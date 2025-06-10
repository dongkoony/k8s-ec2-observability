#!/bin/bash

#################################################################
# ---------------- 워커 노드 자동 설정 스크립트 ------------------
#################################################################

# 로그 설정
readonly LOG_FILE="/home/ubuntu/worker_setup.log"
readonly LOG_PREFIX="[WORKER-${node_index}]"

log() {
    local message="$1"
    echo "$${LOG_PREFIX} $(date '+%Y-%m-%d %H:%M:%S') - $${message}" | tee -a "$${LOG_FILE}"
}

# 변수 설정
MASTER_IP="${master_private_ip}"
NODE_INDEX="${node_index}"
export NODE_ROLE="worker-node$${NODE_INDEX}"

log "워커 노드 $${NODE_INDEX} 자동 설정 시작"
log "마스터 노드 IP: $${MASTER_IP}"

# 시스템 업데이트
log "시스템 업데이트 시작"
apt-get update -y
apt-get upgrade -y

# 필수 패키지 설치
apt-get install -y git curl wget

# 로컬 스크립트 생성 (마스터와 동일한 환경 설정 부분)
log "로컬 설정 스크립트 생성"
mkdir -p /home/ubuntu/k8s-scripts

# 쿠버네티스 설정 스크립트 생성
cat > /home/ubuntu/k8s-scripts/worker_setup.sh << 'WORKER_SCRIPT_EOF'
#!/bin/bash

# 로그 설정
readonly LOG_FILE="/home/ubuntu/worker_k8s_setup.log"
readonly LOG_PREFIX="[K8S-WORKER]"

log() {
    local message="$1"
    echo "$${LOG_PREFIX} $(date '+%Y-%m-%d %H:%M:%S') - $${message}" | tee -a "$${LOG_FILE}"
}

check_error() {
    if [ $? -ne 0 ]; then
        log "오류: $1"
        exit 1
    fi
}

# 쿠버네티스 설정
readonly K8S_VERSION="1.31.0-1.1"
readonly K8S_REPO="https://pkgs.k8s.io/core:/stable:/v1.31/deb/"
readonly K8S_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
readonly K8S_APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

readonly PACKAGES=(
    "kubelet=$${K8S_VERSION}"
    "kubeadm=$${K8S_VERSION}"
    "kubectl=$${K8S_VERSION}"
)

# 커널 모듈 설정
readonly KERNEL_MODULES=(
    "overlay"
    "br_netfilter"
)

readonly SYSCTL_SETTINGS=(
    "net.bridge.bridge-nf-call-iptables=1"
    "net.bridge.bridge-nf-call-ip6tables=1"
    "net.ipv4.ip_forward=1"
)

setup_network() {
    log "네트워크 설정 시작"
    
    # 커널 모듈 로드
    for module in "$${KERNEL_MODULES[@]}"; do
        modprobe "$${module}"
        echo "$${module}" >> /etc/modules-load.d/k8s.conf
    done

    # sysctl 설정
    for setting in "$${SYSCTL_SETTINGS[@]}"; do
        echo "$${setting}" >> /etc/sysctl.d/k8s.conf
    done
    sysctl --system
    check_error "네트워크 설정 실패"

    log "네트워크 설정 완료"
}

install_docker() {
    log "Docker 및 Containerd 설치 시작"
    
    apt-get update -y
    apt-get install -y docker.io
    check_error "Docker 설치 실패"

    systemctl enable --now docker
    check_error "Docker 서비스 활성화 실패"

    # containerd 설정
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl restart containerd
    check_error "containerd 설정 실패"

    log "Docker 및 Containerd 설치 완료"
}

install_kubernetes() {
    log "쿠버네티스 설치 시작"

    # 저장소 설정
    mkdir -p $(dirname $${K8S_KEYRING})
    curl -fsSL $${K8S_REPO}/Release.key | sudo gpg --dearmor -o $${K8S_KEYRING}
    echo "deb [signed-by=$${K8S_KEYRING}] $${K8S_REPO} /" | sudo tee $${K8S_APT_SOURCE}

    # 패키지 설치
    apt-get update
    apt-get install -y "$${PACKAGES[@]}"
    check_error "쿠버네티스 패키지 설치 실패"

    # 버전 고정
    apt-mark hold kubelet kubeadm kubectl
    check_error "쿠버네티스 버전 고정 실패"

    log "쿠버네티스 설치 완료"
}

wait_for_join_command() {
    local master_ip="$1"
    local max_attempts=60  # 10분 대기
    local attempt=1
    
    log "마스터 노드($${master_ip})의 join 명령어 대기 중..."
    
    while [ $${attempt} -le $${max_attempts} ]; do
        if curl -s --connect-timeout 5 http://$${master_ip}:8080/health >/dev/null 2>&1 || \
           curl -s --connect-timeout 5 -k https://$${master_ip}:6443/healthz >/dev/null 2>&1; then
            log "마스터 노드 API 서버 응답 확인됨"
            sleep 30  # 조금 더 대기
            break
        fi
        
        log "마스터 노드 대기 중... ($${attempt}/$${max_attempts})"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $${attempt} -gt $${max_attempts} ]; then
        log "마스터 노드 연결 실패"
        return 1
    fi
    
    return 0
}

join_cluster() {
    local master_ip="$1"
    
    # 마스터 노드 대기
    if ! wait_for_join_command "$${master_ip}"; then
        log "마스터 노드 연결 실패"
        return 1
    fi
    
    # kubeadm join 명령어 생성 (임시 방법)
    log "클러스터 조인 시도"
    
    # 마스터에서 토큰 정보 가져오기 (간단한 방법)
    # 실제로는 마스터에서 생성된 join 명령어를 사용해야 함
    local join_cmd="kubeadm join $${master_ip}:6443 --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification"
    
    # 실제 join 실행은 마스터에서 토큰을 받아야 하므로 주석 처리
    # $${join_cmd}
    
    log "클러스터 조인을 위해 수동 설정이 필요합니다"
    log "마스터 노드에서 'kubeadm token create --print-join-command' 실행 후 해당 명령어를 사용하세요"
    
    return 0
}

main() {
    log "워커 노드 설정 시작"
    
    setup_network
    install_docker
    install_kubernetes
    
    # 클러스터 조인은 마스터 노드 준비 후 수행
    if [ ! -z "$1" ]; then
        join_cluster "$1"
    fi
    
    log "워커 노드 설정 완료"
}

# 스크립트 실행
main "$@"
WORKER_SCRIPT_EOF

# 스크립트 실행 권한 부여
chmod +x /home/ubuntu/k8s-scripts/worker_setup.sh

# 워커 노드 설정 실행
log "Kubernetes 워커 노드 설정 실행"
cd /home/ubuntu/k8s-scripts
./worker_setup.sh "$${MASTER_IP}"

# 소유권 설정
chown -R ubuntu:ubuntu /home/ubuntu/

log "워커 노드 $${NODE_INDEX} 자동 설정 완료"

# 추가: 마스터 노드 준비 대기 및 자동 조인을 위한 백그라운드 스크립트
cat > /home/ubuntu/auto_join.sh << 'AUTO_JOIN_EOF'
#!/bin/bash

MASTER_IP="${master_private_ip}"
LOG_FILE="/home/ubuntu/auto_join.log"

log() {
    echo "[AUTO-JOIN] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$${LOG_FILE}"
}

# 마스터 노드의 join 명령어 파일 대기
log "마스터 노드 join 명령어 대기 시작"
for i in $(seq 1 120); do  # 20분 대기
    if curl -s --connect-timeout 5 -k https://$${MASTER_IP}:6443/healthz | grep -q "ok"; then
        log "마스터 노드 API 서버 정상 확인"
        
        # 잠시 대기 후 join 시도
        sleep 60
        
        # 실제 운영에서는 보안을 위해 토큰을 안전하게 전달받아야 함
        log "클러스터 조인 준비 완료"
        log "수동으로 마스터 노드에서 생성된 join 명령어를 실행하세요"
        break
    fi
    
    log "마스터 노드 대기 중... ($${i}/120)"
    sleep 10
done
AUTO_JOIN_EOF

chmod +x /home/ubuntu/auto_join.sh
chown ubuntu:ubuntu /home/ubuntu/auto_join.sh

# 백그라운드에서 자동 조인 스크립트 실행
nohup /home/ubuntu/auto_join.sh > /home/ubuntu/auto_join_bg.log 2>&1 &

log "워커 노드 $${NODE_INDEX} 설정 및 자동 조인 스크립트 실행 완료" 