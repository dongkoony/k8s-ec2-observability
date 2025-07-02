#!/bin/bash

# Self-managed Kubernetes용 Port-forward 관리 스크립트
# Self-managed 환경에서 NodePort 문제 시 kubectl port-forward 관리

set -e

# 컬러 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

function show_usage() {
    echo -e "${BLUE}k8s-ec2-observability Port-forward 관리${NC}"
    echo ""
    echo "사용법: $0 [명령어]"
    echo ""
    echo "명령어:"
    echo "  start     - 외부 접속을 위한 port-forward 시작"
    echo "  stop      - 모든 port-forward 프로세스 중지"
    echo "  status    - 현재 port-forward 상태 보기"
    echo "  restart   - port-forward 서비스 재시작"
    echo "  logs      - port-forward 로그 보기"
    echo ""
    echo "외부 접속 URL (port-forward 활성화 시):"
    echo "  Bookinfo:  http://$(curl -s ifconfig.me 2>/dev/null || echo 'Your_Public_IP'):30080/productpage"
    echo "  Grafana:   http://$(curl -s ifconfig.me 2>/dev/null || echo 'Your_Public_IP'):30300 (admin/admin)"
}

function start_port_forward() {
    log_info "port-forward 서비스를 시작하고 있습니다..."
    
    # 기존 port-forward 프로세스 중지
    stop_port_forward > /dev/null 2>&1
    
    # 서비스가 준비될 때까지 대기
    log_info "서비스가 준비될 때까지 기다리고 있습니다..."
    kubectl wait --for=condition=ready pod -l app=productpage -n bookinfo --timeout=60s || {
        log_error "Bookinfo productpage pod가 준비되지 않았습니다"
        return 1
    }
    
    # Bookinfo port-forward 시작
    log_info "Bookinfo port-forward를 시작하고 있습니다 (30080 -> 9080)..."
    nohup kubectl port-forward -n bookinfo --address 0.0.0.0 svc/productpage 30080:9080 \
        > /tmp/bookinfo-portforward.log 2>&1 &
    echo $! > /tmp/bookinfo-portforward.pid
    
    # Grafana port-forward 시작 (NodePort로 이미 접속 가능하지 않은 경우)
    if ! timeout 5 curl -s http://localhost:30300/login > /dev/null 2>&1; then
        log_info "Grafana port-forward를 시작하고 있습니다 (30300 -> 80)..."
        nohup kubectl port-forward -n monitoring --address 0.0.0.0 svc/prometheus-grafana 30300:80 \
            > /tmp/grafana-portforward.log 2>&1 &
        echo $! > /tmp/grafana-portforward.pid
    else
        log_info "Grafana는 이미 NodePort를 통해 접속 가능합니다"
    fi
    
    # port-forward 시작 대기
    sleep 5
    
    # port-forward 상태 확인
    if ss -tulpn | grep -q ":30080" && ss -tulpn | grep -q ":30300"; then
        log_info "✅ port-forward 서비스가 성공적으로 시작되었습니다"
        show_access_info
    else
        log_error "❌ 일부 port-forward 서비스 시작에 실패했습니다"
        show_status
    fi
}

function stop_port_forward() {
    log_info "port-forward 서비스를 중지하고 있습니다..."
    
    # PID 파일로 중지
    if [ -f /tmp/bookinfo-portforward.pid ]; then
        if kill -0 $(cat /tmp/bookinfo-portforward.pid) 2>/dev/null; then
            kill $(cat /tmp/bookinfo-portforward.pid)
            log_info "Bookinfo port-forward를 중지했습니다"
        fi
        rm -f /tmp/bookinfo-portforward.pid
    fi
    
    if [ -f /tmp/grafana-portforward.pid ]; then
        if kill -0 $(cat /tmp/grafana-portforward.pid) 2>/dev/null; then
            kill $(cat /tmp/grafana-portforward.pid)
            log_info "Grafana port-forward를 중지했습니다"
        fi
        rm -f /tmp/grafana-portforward.pid
    fi
    
    # 대체 방법: 프로세스 패턴으로 종료
    pkill -f "kubectl.*port-forward.*30080" 2>/dev/null || true
    pkill -f "kubectl.*port-forward.*30300" 2>/dev/null || true
    
    log_info "✅ port-forward 서비스가 중지되었습니다"
}

function show_status() {
    echo -e "${BLUE}=== Port-forward 상태 ===${NC}"
    
    echo ""
    echo "활성 port-forward 프로세스:"
    if pgrep -f "kubectl.*port-forward" > /dev/null; then
        ps aux | grep "kubectl.*port-forward" | grep -v grep
    else
        echo "  port-forward 프로세스를 찾을 수 없습니다"
    fi
    
    echo ""
    echo "포트 바인딩 상태:"
    ss -tulpn | grep ":30080\|:30300" | while read line; do
        echo "  $line"
    done
    
    echo ""
    echo "서비스 접속 테스트:"
    if timeout 3 curl -s http://localhost:30080/productpage > /dev/null 2>&1; then
        echo -e "  Bookinfo (30080): ${GREEN}✅ 접속 가능${NC}"
    else
        echo -e "  Bookinfo (30080): ${RED}❌ 접속 불가${NC}"
    fi
    
    if timeout 3 curl -s http://localhost:30300/login > /dev/null 2>&1; then
        echo -e "  Grafana (30300):  ${GREEN}✅ 접속 가능${NC}"
    else
        echo -e "  Grafana (30300):  ${RED}❌ 접속 불가${NC}"
    fi
}

function show_access_info() {
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Your_Public_IP")
    
    echo ""
    echo -e "${BLUE}=== 외부 접속 URL ===${NC}"
    echo -e "🔗 Bookinfo:  ${GREEN}http://${PUBLIC_IP}:30080/productpage${NC}"
    echo -e "🔗 Grafana:   ${GREEN}http://${PUBLIC_IP}:30300${NC} (admin/admin)"
    echo ""
    echo -e "${YELLOW}참고: AWS Security Group에서 포트 30080과 30300이 허용되어 있는지 확인하세요${NC}"
}

function show_logs() {
    echo -e "${BLUE}=== Port-forward 로그 ===${NC}"
    
    echo ""
    echo "Bookinfo port-forward 로그:"
    if [ -f /tmp/bookinfo-portforward.log ]; then
        tail -10 /tmp/bookinfo-portforward.log
    else
        echo "  로그 파일을 찾을 수 없습니다"
    fi
    
    echo ""
    echo "Grafana port-forward 로그:"
    if [ -f /tmp/grafana-portforward.log ]; then
        tail -10 /tmp/grafana-portforward.log
    else
        echo "  로그 파일을 찾을 수 없습니다"
    fi
}

# 메인 명령어 처리
case "${1:-}" in
    start)
        start_port_forward
        ;;
    stop)
        stop_port_forward
        ;;
    status)
        show_status
        ;;
    restart)
        log_info "port-forward 서비스를 재시작하고 있습니다..."
        stop_port_forward
        sleep 2
        start_port_forward
        ;;
    logs)
        show_logs
        ;;
    *)
        show_usage
        ;;
esac 