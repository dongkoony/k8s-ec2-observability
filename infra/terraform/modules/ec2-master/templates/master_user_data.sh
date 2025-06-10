#!/bin/bash

#################################################################
# ---------------- 마스터 노드 자동 설정 스크립트 ------------------
#################################################################

# 로그 설정
readonly LOG_FILE="/home/ubuntu/master_setup.log"
readonly LOG_PREFIX="[MASTER-SETUP]"

log() {
    local message="$1"
    echo "$${LOG_PREFIX} $(date '+%Y-%m-%d %H:%M:%S') - $${message}" | tee -a "$${LOG_FILE}"
}

# 노드 역할 설정
export NODE_ROLE="master"

log "마스터 노드 자동 설정 시작"

# 시스템 업데이트
log "시스템 업데이트 시작"
apt-get update -y
apt-get upgrade -y

# Git 설치 (스크립트 다운로드용)
apt-get install -y git curl wget

# 프로젝트 클론 (스크립트 접근용)
log "설정 스크립트 다운로드"
cd /home/ubuntu
if [ ! -d "k8s-ec2-observability" ]; then
    git clone https://github.com/your-repo/k8s-ec2-observability.git || {
        log "Git 클론 실패 - 로컬 스크립트 생성"
        mkdir -p k8s-ec2-observability/scripts
        
        # combined_settings.sh 내용을 직접 삽입
        cat > k8s-ec2-observability/scripts/combined_settings.sh << 'SCRIPT_EOF'
#!/bin/bash

#################################################################
# ---------------- 환경 변수 설정 섹션 ------------------
#################################################################

# 로그 설정
readonly LOG_FILE="/home/ubuntu/combined_settings.log"
readonly LOG_PREFIX="[K8S-SETUP]"

# AWS EC2 메타데이터
readonly EC2_METADATA_URL="http://169.254.169.254/latest/meta-data"
readonly EC2_LOCAL_IP=$(curl -s $${EC2_METADATA_URL}/local-ipv4)
readonly EC2_PUBLIC_IP=$(curl -s $${EC2_METADATA_URL}/public-ipv4)

# 네트워크 설정
readonly POD_CIDR="10.244.0.0/16"
readonly SERVICE_CIDR="10.96.0.0/12"
readonly DNS_DOMAIN="cluster.local"
readonly CNI_VERSION="v3.28.0"
readonly CNI_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/$${CNI_VERSION}/manifests/tigera-operator.yaml"
readonly CNI_MANIFEST_CUSTOM="https://raw.githubusercontent.com/projectcalico/calico/$${CNI_VERSION}/manifests/custom-resources.yaml"

# 쿠버네티스 설정
readonly K8S_VERSION="1.31.0-1.1"
readonly K8S_REPO="https://pkgs.k8s.io/core:/stable:/v1.31/deb/"
readonly K8S_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
readonly K8S_APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"
readonly K8S_CONFIG_DIR="/etc/kubernetes"
readonly KUBECONFIG="/home/ubuntu/.kube/config"

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

# 재시도 설정
readonly MAX_RETRIES=3
readonly RETRY_INTERVAL=30
readonly WAIT_INTERVAL=10

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

initialize_master() {
    log "마스터 노드 초기화 시작"

    # kubeadm 설정 생성
    cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $${EC2_LOCAL_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  serviceSubnet: $${SERVICE_CIDR}
  podSubnet: $${POD_CIDR}
  dnsDomain: $${DNS_DOMAIN}
EOF

    # 마스터 노드 초기화
    if kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs --ignore-preflight-errors=Swap > /var/log/kubeadm_init.log 2>&1; then
        log "마스터 노드 초기화 성공"
    else
        log "마스터 노드 초기화 실패"
        cat /var/log/kubeadm_init.log
        return 1
    fi

    # kubeconfig 설정
    mkdir -p $(dirname $${KUBECONFIG})
    cp -i $${K8S_CONFIG_DIR}/admin.conf $${KUBECONFIG}
    chown $(id -u ubuntu):$(id -g ubuntu) $${KUBECONFIG}

    # Join 명령어 생성
    log "Join 명령어 생성 중..."
    kubeadm token create --print-join-command > /home/ubuntu/join_command
    chown ubuntu:ubuntu /home/ubuntu/join_command
    chmod 644 /home/ubuntu/join_command
    
    log "마스터 노드 초기화 완료"
    return 0
}

install_cni() {
    log "Calico CNI 설치 시작"
    
    # 작업 디렉토리 생성
    mkdir -p ~/calico && cd ~/calico

    # Tigera Operator 설치
    curl -LO $${CNI_MANIFEST}
    kubectl create -f tigera-operator.yaml

    # Operator 설치 대기
    sleep 20

    # Custom Resources 설치
    curl -LO $${CNI_MANIFEST_CUSTOM}
    sed -i "s|cidr: .*|cidr: $${POD_CIDR}|g" custom-resources.yaml
    kubectl create -f custom-resources.yaml

    # 설치 후 초기화 대기
    sleep 30
    
    log "Calico CNI 설치 완료"
    return 0
}

main() {
    log "설치 스크립트 시작"
    
    setup_network
    install_docker
    install_kubernetes
    initialize_master
    install_cni
    
    log "설치 스크립트 완료"
}

# 노드 역할이 master인 경우에만 실행
if [[ "$${NODE_ROLE}" == "master" ]]; then
    main
fi
SCRIPT_EOF
    }
fi

# 스크립트 실행 권한 부여
chmod +x k8s-ec2-observability/scripts/combined_settings.sh

# 마스터 노드 설정 실행
log "Kubernetes 마스터 노드 설정 실행"
cd k8s-ec2-observability/scripts
export NODE_ROLE="master"
./combined_settings.sh

# 설정 완료 확인
log "마스터 노드 설정 완료 확인"
if [ -f /home/ubuntu/join_command ]; then
    log "Join 명령어 파일 생성 확인됨"
    chmod 644 /home/ubuntu/join_command
    chown ubuntu:ubuntu /home/ubuntu/join_command
else
    log "경고: Join 명령어 파일이 생성되지 않음"
fi

# 소유권 설정
chown -R ubuntu:ubuntu /home/ubuntu/

log "마스터 노드 자동 설정 완료" 