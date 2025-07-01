#!/bin/bash

# Deploy Observability Stack
# Feature branch: feature/linkerd
# Infrastructure as Code 방식으로 전체 스택 배포

set -e

echo "🚀 Starting Observability Stack deployment..."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Prometheus Stack deployment
log_info "Step 1: Deploying Prometheus Stack..."

# Helm 설치 확인
if ! command -v helm &> /dev/null; then
    log_info "Installing Helm..."
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

# Prometheus Stack 설치
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values manifests/observability/prometheus-stack-values.yml \
    --wait --timeout=10m

log_info "✅ Prometheus Stack deployed successfully"

# Step 2: Linkerd installation
log_info "Step 2: Installing Linkerd..."

# Linkerd CLI 설치 (stable 버전)
if ! command -v linkerd &> /dev/null; then
    log_info "Installing Linkerd CLI (stable version)..."
    curl -fsL https://github.com/linkerd/linkerd2/releases/download/stable-2.14.10/linkerd2-cli-stable-2.14.10-linux-amd64 \
        -o linkerd && chmod +x linkerd && sudo mv linkerd /usr/local/bin/
fi

# Pre-check
log_info "Running Linkerd pre-check..."
linkerd check --pre

# Generate actual manifests
log_info "Generating Linkerd manifests..."
linkerd install --crds > manifests/linkerd/install-crds.yml
linkerd install > manifests/linkerd/install-control-plane.yml
linkerd viz install > manifests/linkerd/install-viz.yml

# Apply Linkerd manifests
log_info "Applying Linkerd CRDs..."
kubectl apply -f manifests/linkerd/install-crds.yml

log_info "Applying Linkerd Control Plane..."
kubectl apply -f manifests/linkerd/install-control-plane.yml

log_info "Waiting for Linkerd Control Plane to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment -n linkerd --all

log_info "Applying Linkerd Viz..."
kubectl apply -f manifests/linkerd/install-viz.yml

log_info "✅ Linkerd deployed successfully"

# Step 3: Bookinfo application
log_info "Step 3: Deploying Bookinfo application..."

# Download original Bookinfo manifest
curl -L https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml -o /tmp/bookinfo-original.yml

# Apply namespace first (with Linkerd injection)
kubectl apply -f manifests/applications/bookinfo-with-linkerd.yml

# Apply original Bookinfo deployments to the injection-enabled namespace
kubectl apply -f /tmp/bookinfo-original.yml -n bookinfo

log_info "✅ Bookinfo application deployed successfully"

# Step 4: Traffic generation
log_info "Step 4: Starting traffic generation..."
kubectl apply -f manifests/applications/traffic-generator.yml

log_info "✅ Traffic generator deployed successfully"

# Final status check
log_info "🎯 Final status check..."

echo ""
log_info "Prometheus Stack:"
kubectl get pods -n monitoring

echo ""
log_info "Linkerd:"
kubectl get pods -n linkerd
kubectl get pods -n linkerd-viz

echo ""
log_info "Bookinfo:"
kubectl get pods -n bookinfo

echo ""
log_info "Services:"
kubectl get svc -n monitoring | grep -E "(grafana|prometheus)"
kubectl get svc -n bookinfo

echo ""
log_info "🎉 Observability Stack deployment completed!"
log_info "📊 Access points:"
log_info "   Grafana: http://$(curl -s ifconfig.me):30300 (admin/prom-operator)"
log_info "   Bookinfo: http://$(curl -s ifconfig.me):30080/productpage"
log_info "   Linkerd Dashboard: linkerd viz dashboard" 