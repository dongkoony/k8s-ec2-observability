#!/bin/bash

#############################################
# Auto Recovery System for k8s-ec2-observability
# Step 8: 실전 운영 자동화 & 신뢰성 완성
# 마스터노드 IP: ip-10-0-1-34 (13.209.82.167)
#############################################

set -euo pipefail

# 설정 변수
MASTER_NODE="ip-10-0-1-34"
LOG_FILE="/tmp/auto-recovery-$(date +%Y%m%d).log"
CHECK_INTERVAL=30
DRY_RUN=false

# 파라미터 처리
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🧪 DRY RUN MODE - 실제 변경 없이 점검만 수행"
fi

# 로깅 함수
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

# 실행 함수 (DRY RUN 지원)
execute() {
    local cmd="$1"
    local description="$2"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "🔍 [DRY RUN] ${description}: ${cmd}"
        return 0
    else
        log "⚡ ${description}: ${cmd}"
        eval "${cmd}" 2>&1 | tee -a "${LOG_FILE}" || log "❌ 실행 실패: ${cmd}"
    fi
}

# 마스터 노드로 강제 이동 함수
force_to_master() {
    local namespace=$1
    local deployment=$2
    
    log "🔄 ${deployment} (${namespace})을 마스터노드로 강제 이동 중..."
    
    local patch_cmd="kubectl patch deployment ${deployment} -n ${namespace} -p '{
        \"spec\": {
            \"template\": {
                \"spec\": {
                    \"nodeSelector\": {
                        \"kubernetes.io/hostname\": \"${MASTER_NODE}\"
                    },
                    \"tolerations\": [
                        {
                            \"key\": \"node-role.kubernetes.io/control-plane\",
                            \"operator\": \"Exists\",
                            \"effect\": \"NoSchedule\"
                        }
                    ]
                }
            }
        }
    }'"
    
    execute "${patch_cmd}" "마스터노드 강제 배치"
}

# 1. OOMKilled Pod 자동 복구
check_oomkilled_pods() {
    log "🔍 OOMKilled Pod 검사 중..."
    
    local oomkilled_pods
    oomkilled_pods=$(kubectl get pods -A -o json | jq -r '
        .items[] | 
        select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled" and 
               (.metadata.name | test("heartbeat|exporter") | not)) |
        "\(.metadata.namespace)/\(.metadata.name)"
    ' 2>/dev/null | grep -v "^$" || echo "")
    
    if [[ -n "${oomkilled_pods}" ]]; then
        log "🚨 OOMKilled Pod 발견:"
        echo "${oomkilled_pods}" | while IFS= read -r pod_info; do
            if [[ -n "${pod_info}" ]]; then
                namespace=$(echo "${pod_info}" | cut -d'/' -f1)
                pod_name=$(echo "${pod_info}" | cut -d'/' -f2)
                log "   - ${pod_name} (${namespace})"
                
                execute "kubectl delete pod ${pod_name} -n ${namespace}" "OOMKilled Pod 재시작"
            fi
        done
    else
        log "✅ OOMKilled Pod 없음"
    fi
}

# 2. Pending Pod 처리 및 리소스 최적화
check_pending_pods() {
    log "🔍 Pending Pod 및 리소스 상태 검사 중..."
    
    local pending_count
    pending_count=$(kubectl get pods -A --field-selector=status.phase=Pending -o json | jq '.items | length' 2>/dev/null || echo "0")
    
    if [[ ${pending_count} -gt 0 ]]; then
        log "⚠️  Pending Pod ${pending_count}개 발견"
        
        # CPU 사용량 확인
        local cpu_usage
        cpu_usage=$(kubectl top node ${MASTER_NODE} --no-headers 2>/dev/null | awk '{print $3}' | tr -d '%' || echo "0")
        
        log "📊 마스터노드 CPU 사용률: ${cpu_usage}%"
        
        if [[ ${cpu_usage} -gt 90 ]]; then
            log "🚨 높은 CPU 사용률 감지 - 리소스 최적화 실행"
            
            # 우선순위 낮은 Pod 스케일 다운
            execute "kubectl scale deployment reviews-v2 -n bookinfo --replicas=0" "reviews-v2 스케일 다운"
            execute "kubectl scale deployment reviews-v3 -n bookinfo --replicas=0" "reviews-v3 스케일 다운"
        fi
    else
        log "✅ Pending Pod 없음"
    fi
}

# 3. Linkerd 상태 검사 및 복구
check_linkerd_health() {
    log "🔍 Linkerd 상태 검사 중..."
    
    local linkerd_check_result
    linkerd_check_result=$(linkerd check --proxy 2>/dev/null | grep "√" | wc -l || echo "0")
    
    log "🔗 Linkerd 정상 체크: ${linkerd_check_result}개"
    
    if [[ ${linkerd_check_result} -lt 10 ]]; then
        log "🚨 Linkerd 상태 이상 감지"
        
        # 실패한 Linkerd Pod 확인 (heartbeat 제외)
        local failed_linkerd_pods
        failed_linkerd_pods=$(kubectl get pods -n linkerd -o json | jq -r '
            .items[] | 
            select(.status.phase != "Running" and (.metadata.name | test("heartbeat") | not)) |
            .metadata.name
        ' 2>/dev/null | grep -v "^$" || echo "")
        
        if [[ -n "${failed_linkerd_pods}" ]]; then
            log "🔄 실패한 Linkerd Pod 재시작:"
            echo "${failed_linkerd_pods}" | while IFS= read -r pod_name; do
                if [[ -n "${pod_name}" ]]; then
                    log "   - ${pod_name}"
                    execute "kubectl delete pod ${pod_name} -n linkerd" "Linkerd Pod 재시작"
                fi
            done
        fi
    else
        log "✅ Linkerd 상태 정상"
    fi
}

# 4. 모니터링 스택 상태 검사
check_monitoring_health() {
    log "🔍 모니터링 스택 상태 검사 중..."
    
    local prometheus_status
    prometheus_status=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
    
    local grafana_status  
    grafana_status=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
    
    log "📊 Prometheus: ${prometheus_status}, Grafana: ${grafana_status}"
    
    if [[ "${prometheus_status}" != "Running" ]] || [[ "${grafana_status}" != "Running" ]]; then
        log "🚨 모니터링 스택 이상 감지"
        
        if [[ "${prometheus_status}" != "Running" ]]; then
            execute "kubectl delete pods -n monitoring -l app.kubernetes.io/name=prometheus" "Prometheus 재시작"
        fi
        
        if [[ "${grafana_status}" != "Running" ]]; then
            execute "kubectl delete pods -n monitoring -l app.kubernetes.io/name=grafana" "Grafana 재시작"
        fi
    else
        log "✅ 모니터링 스택 정상"
    fi
}

# 5. 전체 시스템 상태 보고
system_status_report() {
    log "📋 시스템 상태 보고서 생성 중..."
    
    local total_pods
    total_pods=$(kubectl get pods -A --no-headers | wc -l)
    
    local running_pods
    running_pods=$(kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l)
    
    local error_pods
    error_pods=$(kubectl get pods -A | grep -c "Error\|CrashLoopBackOff\|ImagePullBackOff" || echo "0")
    
    local pending_pods
    pending_pods=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers | wc -l)
    
    log "📊 시스템 상태 요약:"
    log "   전체 Pod: ${total_pods}개"
    log "   실행 중: ${running_pods}개"
    log "   오류: ${error_pods}개"
    log "   대기 중: ${pending_pods}개"
    log "   성공률: $(( running_pods * 100 / total_pods ))%"
}

# 메인 실행 함수
main() {
    log "🚀 Auto Recovery System 시작 (마스터노드: ${MASTER_NODE})"
    log "📂 로그 파일: ${LOG_FILE}"
    
    # 모든 검사 실행
    check_oomkilled_pods
    check_pending_pods  
    check_linkerd_health
    check_monitoring_health
    system_status_report
    
    log "✅ Auto Recovery System 완료"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "🧪 DRY RUN 모드 완료 - 실제 변경사항 없음"
    fi
}

# 스크립트 실행
main "$@" 