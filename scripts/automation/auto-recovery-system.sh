#!/bin/bash

#############################################
# Auto Recovery System for k8s-ec2-observability
# Step 8: Real-world Observability Implementation
#############################################

set -euo pipefail

# 설정 변수
MASTER_NODE="ip-10-0-1-34"
LOG_FILE="/tmp/auto-recovery.log"
CHECK_INTERVAL=30

# 로깅 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# 마스터 노드로 강제 이동 함수
force_to_master() {
    local namespace=$1
    local deployment=$2
    
    log "🔄 Moving ${deployment} in ${namespace} to master node..."
    
    kubectl patch deployment "${deployment}" -n "${namespace}" -p "{
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
    }" 2>/dev/null || log "⚠️  Failed to patch ${deployment}"
}

# 1. OOMKilled Pod 자동 복구
check_oomkilled_pods() {
    log "🔍 Checking for OOMKilled pods..."
    
    local oomkilled_pods
    oomkilled_pods=$(kubectl get pods -A -o json | jq -r '
        .items[] | 
        select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") |
        "\(.metadata.namespace)/\(.metadata.name)"
    ' 2>/dev/null || echo "")
    
    if [[ -n "${oomkilled_pods}" ]]; then
        log "🚨 Found OOMKilled pods: ${oomkilled_pods}"
        
        # OOMKilled된 포드들 재시작
        echo "${oomkilled_pods}" | while read -r pod_info; do
            if [[ -n "${pod_info}" ]]; then
                namespace=$(echo "${pod_info}" | cut -d'/' -f1)
                pod_name=$(echo "${pod_info}" | cut -d'/' -f2)
                
                log "♻️  Restarting OOMKilled pod: ${pod_name} in ${namespace}"
                kubectl delete pod "${pod_name}" -n "${namespace}" 2>/dev/null || true
            fi
        done
    fi
}

# 2. 리소스 부족으로 Pending인 Pod 처리
check_pending_pods() {
    log "🔍 Checking for resource-constrained pending pods..."
    
    local pending_pods
    pending_pods=$(kubectl get pods -A -o json | jq -r '
        .items[] | 
        select(.status.phase == "Pending" and .status.conditions[]?.reason == "Unschedulable") |
        "\(.metadata.namespace)/\(.metadata.name)"
    ' 2>/dev/null || echo "")
    
    if [[ -n "${pending_pods}" ]]; then
        log "⚠️  Found pending pods due to resource constraints: ${pending_pods}"
        
        # CPU 사용량 확인
        local cpu_usage
        cpu_usage=$(kubectl describe node "${MASTER_NODE}" | grep -A3 "Allocated resources" | grep "cpu" | awk '{print $2}' | sed 's/[()%]//g' || echo "0")
        
        if [[ "${cpu_usage:-0}" -gt 95 ]]; then
            log "🚨 Master node CPU usage is ${cpu_usage}% - Need resource optimization!"
            
            # 우선순위가 낮은 포드 스케일 다운 (예: reviews v2, v3)
            kubectl scale deployment reviews-v2 -n bookinfo --replicas=0 2>/dev/null || true
            kubectl scale deployment reviews-v3 -n bookinfo --replicas=0 2>/dev/null || true
            
            log "📉 Scaled down low-priority deployments to free resources"
        fi
    fi
}

# 3. 서비스 상태 모니터링 및 복구
check_service_health() {
    log "🔍 Checking critical service health..."
    
    # Linkerd 상태 확인
    local linkerd_status
    linkerd_status=$(linkerd check --proxy 2>/dev/null | grep -c "√" || echo "0")
    
    if [[ "${linkerd_status}" -lt 5 ]]; then
        log "🚨 Linkerd health issues detected, attempting recovery..."
        
        # Linkerd 컴포넌트 재시작
        kubectl rollout restart deployment -n linkerd 2>/dev/null || true
        kubectl rollout restart deployment -n linkerd-viz 2>/dev/null || true
    fi
    
    # Prometheus Stack 상태 확인
    local failed_pods
    failed_pods=$(kubectl get pods -n monitoring --no-headers | grep -v "Running\|Completed" | wc -l || echo "0")
    
    if [[ "${failed_pods}" -gt 0 ]]; then
        log "🚨 Found ${failed_pods} failed monitoring pods, restarting..."
        kubectl rollout restart deployment -n monitoring 2>/dev/null || true
    fi
}

# 4. Linkerd 프록시 주입 상태 확인 및 복구
check_linkerd_injection() {
    log "🔍 Checking Linkerd proxy injection status..."
    
    # bookinfo 네임스페이스의 포드 중 프록시가 없는 것들 확인
    local pods_without_proxy
    pods_without_proxy=$(kubectl get pods -n bookinfo -o json | jq -r '
        .items[] | 
        select(.spec.containers | length == 1) |
        .metadata.name
    ' 2>/dev/null || echo "")
    
    if [[ -n "${pods_without_proxy}" ]]; then
        log "🔄 Found pods without Linkerd proxy, restarting for injection..."
        
        # bookinfo 네임스페이스 annotation 재확인
        kubectl annotate namespace bookinfo linkerd.io/inject=enabled --overwrite 2>/dev/null || true
        
        # 프록시가 없는 포드들 재시작
        echo "${pods_without_proxy}" | while read -r pod_name; do
            if [[ -n "${pod_name}" ]]; then
                log "♻️  Restarting pod for proxy injection: ${pod_name}"
                kubectl delete pod "${pod_name}" -n bookinfo 2>/dev/null || true
            fi
        done
    fi
}

# 5. 마스터 노드 리소스 최적화
optimize_master_node() {
    log "🔧 Optimizing master node resource allocation..."
    
    # 모든 중요 컴포넌트가 마스터 노드에 있는지 확인
    local namespaces=("linkerd" "linkerd-viz" "monitoring" "bookinfo")
    
    for ns in "${namespaces[@]}"; do
        log "🔍 Checking deployments in namespace: ${ns}"
        
        local deployments
        deployments=$(kubectl get deployments -n "${ns}" -o name 2>/dev/null | sed 's/deployment.apps\///' || echo "")
        
        echo "${deployments}" | while read -r deployment; do
            if [[ -n "${deployment}" ]]; then
                # 현재 배치된 노드 확인
                local current_node
                current_node=$(kubectl get pods -n "${ns}" -l app="${deployment}" -o json 2>/dev/null | jq -r '.items[0].spec.nodeName // empty' || echo "")
                
                if [[ "${current_node}" != "${MASTER_NODE}" && -n "${current_node}" ]]; then
                    log "🚚 Moving ${deployment} from ${current_node} to master node"
                    force_to_master "${ns}" "${deployment}"
                fi
            fi
        done
    done
}

# 6. 실시간 메트릭 수집
collect_metrics() {
    log "📊 Collecting system metrics..."
    
    # 노드 리소스 사용량
    kubectl describe node "${MASTER_NODE}" | grep -A5 "Allocated resources" | tee -a "${LOG_FILE}"
    
    # 포드 상태 요약
    log "📋 Pod Status Summary:"
    kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c | tee -a "${LOG_FILE}"
    
    # Linkerd 상태
    log "🔗 Linkerd Status:"
    linkerd check --proxy 2>/dev/null | tail -5 | tee -a "${LOG_FILE}" || log "Linkerd check failed"
}

# 메인 복구 루프
main_recovery_loop() {
    log "🚀 Starting Auto Recovery System for k8s-ec2-observability"
    log "🎯 Target: ${MASTER_NODE}"
    log "⏰ Check interval: ${CHECK_INTERVAL} seconds"
    
    while true; do
        log "🔄 Starting recovery cycle..."
        
        # 모든 체크 함수 실행
        check_oomkilled_pods
        check_pending_pods
        check_service_health
        check_linkerd_injection
        optimize_master_node
        collect_metrics
        
        log "✅ Recovery cycle completed. Next check in ${CHECK_INTERVAL} seconds..."
        sleep "${CHECK_INTERVAL}"
    done
}

# 스크립트 실행
case "${1:-run}" in
    "run")
        main_recovery_loop
        ;;
    "test")
        log "🧪 Running one-time test cycle..."
        check_oomkilled_pods
        check_pending_pods
        check_service_health
        check_linkerd_injection
        optimize_master_node
        collect_metrics
        log "✅ Test cycle completed"
        ;;
    *)
        echo "Usage: $0 [run|test]"
        echo "  run  - Start continuous auto recovery (default)"
        echo "  test - Run one-time recovery check"
        exit 1
        ;;
esac 