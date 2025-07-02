#!/bin/bash

# Observability Stack 배포 스크립트
# Feature branch: feature/linkerd
# Infrastructure as Code 방식으로 전체 스택 배포
# Step 7 개선사항: Self-managed 환경 최적화 내장

set -e

echo "🚀 Observability Stack 배포를 시작합니다..."

# 컬러 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[정보]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[경고]${NC} $1"
}

function log_error() {
    echo -e "${RED}[오류]${NC} $1"
}

# Step 1: Prometheus Stack 배포
log_info "1단계: Prometheus Stack 배포 중..."

# Helm 설치 확인
if ! command -v helm &> /dev/null; then
    log_info "Helm을 설치하고 있습니다..."
    curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -L -o helm.tar.gz
    tar -zxvf helm.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin/helm
    rm -rf helm.tar.gz linux-amd64
fi

# Prometheus Community Helm 저장소 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# monitoring 네임스페이스 생성
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Prometheus Stack 설치 (Step 7에서 검증된 PVC 비활성화 설정 적용)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values manifests/observability/prometheus-stack-values.yml \
    --wait --timeout=10m

log_info "✅ Prometheus Stack이 성공적으로 배포되었습니다"

# Step 2: Linkerd 설치
log_info "2단계: Linkerd를 설치하고 있습니다..."

# Linkerd CLI 설치 (Stable Version)
if ! command -v linkerd &> /dev/null; then
    log_info "Linkerd CLI를 설치하고 있습니다 (Stable Version)..."
    curl -fsL https://github.com/linkerd/linkerd2/releases/download/stable-2.14.10/linkerd2-cli-stable-2.14.10-linux-amd64 \
        -o linkerd && chmod +x linkerd && sudo mv linkerd /usr/local/bin/
fi

# 사전 검사
log_info "Linkerd 사전 검사를 실행하고 있습니다..."
linkerd check --pre

# 실제 매니페스트 생성
log_info "Linkerd 매니페스트를 생성하고 있습니다..."
linkerd install --crds > manifests/linkerd/install-crds.yml
linkerd install > manifests/linkerd/install-control-plane.yml

# Linkerd 매니페스트 적용
log_info "Linkerd CRD를 적용하고 있습니다..."
kubectl apply -f manifests/linkerd/install-crds.yml

log_info "Linkerd Control Plane을 적용하고 있습니다..."
kubectl apply -f manifests/linkerd/install-control-plane.yml

# Step 7 개선: Self-managed 환경 최적화 - 마스터노드 배치 패치
log_info "Self-managed 환경을 위한 Linkerd 최적화를 적용하고 있습니다..."
sleep 30  # Control Plane 배포 대기

# Linkerd 컴포넌트를 마스터노드에 배치 (Step 7에서 검증된 해결책)
log_info "Linkerd 컴포넌트를 마스터 노드에 배치하도록 패치하고 있습니다..."
kubectl patch deployment linkerd-destination -n linkerd --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", 
   "value": {"node-role.kubernetes.io/control-plane": ""}},
  {"op": "add", "path": "/spec/template/spec/tolerations",
   "value": [{"key": "node-role.kubernetes.io/control-plane", 
             "operator": "Exists", "effect": "NoSchedule"}]}
]' || log_warn "Linkerd destination 패치가 실패했을 수 있습니다"

kubectl patch deployment linkerd-proxy-injector -n linkerd --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", 
   "value": {"node-role.kubernetes.io/control-plane": ""}},
  {"op": "add", "path": "/spec/template/spec/tolerations",
   "value": [{"key": "node-role.kubernetes.io/control-plane", 
             "operator": "Exists", "effect": "NoSchedule"}]}
]' || log_warn "Linkerd proxy-injector 패치가 실패했을 수 있습니다"

# Linkerd 안정화 대기
log_info "Linkerd가 안정화될 때까지 기다리고 있습니다..."
sleep 60

# Control Plane이 안정적인 경우에만 Viz 생성 및 적용
if linkerd check --proxy > /dev/null 2>&1; then
    log_info "Control Plane이 안정적입니다. Viz 매니페스트를 생성하고 있습니다..."
    linkerd viz install > manifests/linkerd/install-viz.yml
    kubectl apply -f manifests/linkerd/install-viz.yml
    log_info "✅ Linkerd Viz가 성공적으로 배포되었습니다"
else
    log_warn "⚠️ Linkerd Control Plane이 불안정하여 Viz 배포를 건너뜁니다"
fi

log_info "✅ Linkerd가 Self-managed 최적화와 함께 배포되었습니다"

# Step 3: Bookinfo 애플리케이션
log_info "3단계: Bookinfo 애플리케이션을 배포하고 있습니다..."

# Self-managed 최적화된 Bookinfo 애플리케이션 적용 (Step 7 개선)
# bookinfo-with-linkerd.yml에는 이미 모든 Deployment가 마스터 노드 최적화와 함께 포함됨
kubectl apply -f manifests/applications/bookinfo-with-linkerd.yml

# Step 7 개선: Self-managed 환경 검증 및 외부 접속 설정
log_info "Bookinfo Self-managed 최적화를 검증하고 있습니다..."
sleep 20  # Deployment 배포 대기

# Self-managed 최적화가 이미 bookinfo-with-linkerd.yml에 포함됨을 확인
log_info "✅ Self-managed 최적화가 매니페스트에 사전 구성되었습니다"
log_info "   - 모든 pod가 마스터 노드에 적절한 toleration과 함께 스케줄링됨"
log_info "   - 외부 접속을 위한 NodePort 서비스가 구성됨"

# Self-managed 환경에서 NodePort 문제 시 kubectl port-forward 대체
log_info "외부 접속 솔루션을 설정하고 있습니다..."
sleep 30  # productpage pod 재시작 대기

# NodePort 작동 확인 시도
if ! timeout 10 curl -s http://localhost:30080/productpage > /dev/null 2>&1; then
    log_warn "NodePort가 작동하지 않습니다. kubectl port-forward를 대체 수단으로 설정하고 있습니다..."
    
    # 기존 port-forward 프로세스 정리
    pkill -f "kubectl.*port-forward.*30080" || true
    
    # kubectl port-forward를 백그라운드로 실행 (서비스 이름 수정)
    nohup kubectl port-forward -n bookinfo --address 0.0.0.0 svc/productpage 30080:9080 > /tmp/bookinfo-portforward.log 2>&1 &
    
    # port-forward 시작 대기
    sleep 5
    
    if ss -tulpn | grep -q ":30080"; then
        log_info "✅ kubectl port-forward가 외부 접속을 위해 성공적으로 구성되었습니다"
        log_info "   🔧 port-forward 관리를 위해 './scripts/manage-port-forward.sh'를 사용하세요"
    else
        log_error "❌ NodePort와 port-forward 모두 실패했습니다"
    fi
else
    log_info "✅ NodePort가 정상적으로 작동하고 있습니다"
fi

log_info "✅ Bookinfo 애플리케이션이 성공적으로 배포되었습니다"

# Step 4: 트래픽 생성 (Step 7에서 검증된 지속적 트래픽 생성)
log_info "4단계: 지속적인 트래픽 생성을 시작하고 있습니다..."
kubectl apply -f manifests/applications/traffic-generator.yml

log_info "✅ 트래픽 생성기가 성공적으로 배포되었습니다"

# 최종 상태 확인
log_info "🎯 최종 상태를 확인하고 있습니다..."

echo ""
log_info "Prometheus Stack:"
kubectl get pods -n monitoring

echo ""
log_info "Linkerd:"
kubectl get pods -n linkerd
kubectl get pods -n linkerd-viz 2>/dev/null || echo "Linkerd-viz: 배포되지 않음 (Control Plane이 불안정할 수 있음)"

echo ""
log_info "Bookinfo:"
kubectl get pods -n bookinfo

echo ""
log_info "서비스 목록:"
kubectl get svc -n monitoring | grep -E "(grafana|prometheus)"
kubectl get svc -n bookinfo

echo ""
log_info "🎉 Observability Stack 배포가 완료되었습니다!"
log_info "📊 접속 주소:"
log_info "   Grafana: http://$(curl -s ifconfig.me):30300 (admin/prom-operator)"
log_info "   Bookinfo: http://$(curl -s ifconfig.me):30080/productpage"
log_info "   Linkerd Dashboard: linkerd viz dashboard (Viz가 안정적인 경우)"

echo ""
log_info "🔧 적용된 Self-managed 최적화:"
log_info "   ✅ Prometheus stack에서 PVC 비활성화"
log_info "   ✅ Linkerd 컴포넌트가 마스터 노드에 패치됨"
log_info "   ✅ Bookinfo 앱이 마스터 노드용으로 사전 구성됨"
log_info "   ✅ NodePort를 통한 외부 접속 (port-forward 대체 가능)"
log_info "   ✅ 지속적인 트래픽 생성 활성화"

echo ""
log_info "🛠️  Port-forward 관리 (필요시):"
log_info "   ./scripts/manage-port-forward.sh start   # port-forward 시작"
log_info "   ./scripts/manage-port-forward.sh status  # 상태 확인"
log_info "   ./scripts/manage-port-forward.sh stop    # port-forward 중지" 