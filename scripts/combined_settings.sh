#!/bin/bash

#################################################################
# ---------------- 환경 변수 설정 섹션 ------------------
#################################################################

# 로그 설정
readonly LOG_FILE="/home/ubuntu/combined_settings.log"
readonly LOG_PREFIX="[K8S-SETUP]"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# AWS EC2 메타데이터
readonly EC2_METADATA_URL="http://169.254.169.254/latest/meta-data"
readonly EC2_LOCAL_IP=$(curl -s ${EC2_METADATA_URL}/local-ipv4)
readonly EC2_PUBLIC_IP=$(curl -s ${EC2_METADATA_URL}/public-ipv4)

# 네트워크 설정
readonly POD_CIDR="10.244.0.0/16"
readonly SERVICE_CIDR="10.96.0.0/12"
readonly DNS_DOMAIN="cluster.local"
readonly CNI_VERSION="v3.28.0"
readonly CNI_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/${CNI_VERSION}/manifests/tigera-operator.yaml"
readonly CNI_MANIFEST_CUSTOM="https://raw.githubusercontent.com/projectcalico/calico/${CNI_VERSION}/manifests/custom-resources.yaml"

# containerd 설정
readonly CONTAINERD_CONFIG="/etc/containerd/config.toml"
readonly CONTAINERD_CONFIG_DIR="/etc/containerd"

# 쿠버네티스 설정
readonly K8S_VERSION="1.31.0-1.1"
readonly K8S_REPO="https://pkgs.k8s.io/core:/stable:/v1.31/deb/"
readonly K8S_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
readonly K8S_APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"
readonly K8S_CONFIG_DIR="/etc/kubernetes"
readonly KUBECONFIG="/home/ubuntu/.kube/config"

readonly PACKAGES=(
    "kubelet=${K8S_VERSION}"
    "kubeadm=${K8S_VERSION}"
    "kubectl=${K8S_VERSION}"
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

# 시스템 요구사항
readonly MIN_CPU_CORES=2
readonly MIN_MEMORY_GB=2
readonly REQUIRED_PORTS=(6443 10250 10251 10252 2379 2380)

# 재시도 설정
readonly MAX_RETRIES=3
readonly RETRY_INTERVAL=30
readonly WAIT_INTERVAL=10

#################################################################
# ---------------- 유틸리티 함수 섹션 ------------------
#################################################################

log() {
    local message="$1"
    echo "${LOG_PREFIX} $(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

check_error() {
    if [ $? -ne 0 ]; then
        log "오류: $1"
        exit 1
    fi
}

wait_for_service() {
    local service_name="$1"
    local max_attempts=30
    local attempt=1

    while ! systemctl is-active --quiet "${service_name}"; do
        if [ ${attempt} -ge ${max_attempts} ]; then
            log "${service_name} 서비스 시작 실패"
            return 1
        fi
        log "${service_name} 서비스 대기 중... (${attempt}/${max_attempts})"
        sleep ${WAIT_INTERVAL}
        attempt=$((attempt + 1))
    done
    return 0
}

verify_system_requirements() {
    log "시스템 요구사항 검증 시작"

    # CPU 코어 수 확인
    local cpu_cores=$(nproc)
    if [ ${cpu_cores} -lt ${MIN_CPU_CORES} ]; then
        log "CPU 코어 수 부족: ${cpu_cores} (필요: ${MIN_CPU_CORES})"
        return 1
    fi

    # 메모리 확인
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ ${memory_gb} -lt ${MIN_MEMORY_GB} ]; then
        log "메모리 부족: ${memory_gb}GB (필요: ${MIN_MEMORY_GB}GB)"
        return 1
    fi

    # 포트 확인
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln | grep ":${port} " > /dev/null; then
            log "포트 ${port}가 이미 사용 중"
            return 1
        fi
    done

    log "시스템 요구사항 검증 완료"
    return 0
}

#################################################################
# ---------------- 네트워크 설정 섹션 ------------------
#################################################################

setup_network() {
    log "네트워크 설정 시작"

    # 커널 모듈 로드
    for module in "${KERNEL_MODULES[@]}"; do
        modprobe "${module}"
        echo "${module}" >> /etc/modules-load.d/k8s.conf
    done

    # sysctl 설정
    for setting in "${SYSCTL_SETTINGS[@]}"; do
        echo "${setting}" >> /etc/sysctl.d/k8s.conf
    done
    sysctl --system
    check_error "네트워크 설정 실패"

    log "네트워크 설정 완료"
}

#################################################################
# ---------------- Docker 및 Containerd 설치 섹션 ------------------
#################################################################

install_docker() {
    log "Docker 및 Containerd 설치 시작"
    
    apt-get update -y
    apt-get install -y docker.io
    check_error "Docker 설치 실패"

    systemctl enable --now docker
    check_error "Docker 서비스 활성화 실패"

    # containerd 설정
    mkdir -p ${CONTAINERD_CONFIG_DIR}
    containerd config default | tee ${CONTAINERD_CONFIG}
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' ${CONTAINERD_CONFIG}
    systemctl restart containerd
    check_error "containerd 설정 실패"

    log "Docker 및 Containerd 설치 완료"
}

#################################################################
# ---------------- 쿠버네티스 설치 섹션 ------------------
#################################################################

install_kubernetes() {
    log "쿠버네티스 설치 시작"

    # 저장소 설정
    mkdir -p $(dirname ${K8S_KEYRING})
    curl -fsSL ${K8S_REPO}/Release.key | sudo gpg --dearmor -o ${K8S_KEYRING}
    echo "deb [signed-by=${K8S_KEYRING}] ${K8S_REPO} /" | sudo tee ${K8S_APT_SOURCE}

    # 패키지 설치
    apt-get update
    apt-get install -y "${PACKAGES[@]}"
    check_error "쿠버네티스 패키지 설치 실패"

    # 버전 고정
    apt-mark hold kubelet kubeadm kubectl
    check_error "쿠버네티스 버전 고정 실패"

    log "쿠버네티스 설치 완료"
}

# #################################################################
# # ---------------- 마스터 노드 초기화 섹션 ------------------
# #################################################################

# initialize_master() {
#     log "마스터 노드 초기화 시작"

#     # kubeadm 설정 생성
#     cat > /tmp/kubeadm-config.yaml <<EOF
# apiVersion: kubeadm.k8s.io/v1beta3
# kind: InitConfiguration
# localAPIEndpoint:
#   advertiseAddress: ${EC2_LOCAL_IP}
#   bindPort: 6443
# nodeRegistration:
#   criSocket: unix:///var/run/containerd/containerd.sock
# ---
# apiVersion: kubeadm.k8s.io/v1beta3
# kind: ClusterConfiguration
# networking:
#   serviceSubnet: ${SERVICE_CIDR}
#   podSubnet: ${POD_CIDR}
#   dnsDomain: ${DNS_DOMAIN}
# EOF

#     # 마스터 노드 초기화
#     local retry_count=0
#     local init_success=false
#     while [ ${retry_count} -lt ${MAX_RETRIES} ]; do
#         if kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs > /var/log/kubeadm_init.log 2>&1; then
#             log "마스터 노드 초기화 성공"
#             init_success=true
#             break
#         fi
#         retry_count=$((retry_count + 1))
#         log "초기화 실패. ${RETRY_INTERVAL}초 후 재시도... (${retry_count}/${MAX_RETRIES})"
#         sleep ${RETRY_INTERVAL}
#     done

#     # 초기화 실패 시 종료
#     if [ "$init_success" = false ]; then
#         log "마스터 노드 초기화 최종 실패"
#         return 1
#     fi

#     # kubeconfig 설정
#     mkdir -p $(dirname ${KUBECONFIG})
#     cp -i ${K8S_CONFIG_DIR}/admin.conf ${KUBECONFIG}
#     chown $(id -u ubuntu):$(id -g ubuntu) ${KUBECONFIG}

#     # CNI 설치
#     if ! install_cni; then
#         log "CNI 설치 실패"
#         return 1
#     fi

#     # Join 명령어 생성
#     log "Join 명령어 생성 중..."
#     kubeadm token create --print-join-command > /home/ubuntu/join_command
#     chown ubuntu:ubuntu /home/ubuntu/join_command
#     chmod 644 /home/ubuntu/join_command
    
#     # Join 명령어 파일 생성 확인
#     if [ ! -f /home/ubuntu/join_command ]; then
#         log "Join 명령어 파일 생성 실패"
#         return 1
#     fi

#     log "마스터 노드 초기화 완료"
#     return 0
# }

#################################################################
# ---------------- 마스터 노드 초기화 섹션 ------------------
#################################################################

initialize_master() {
    log "마스터 노드 초기화 시작"

    # kubeadm 설정 생성
    cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${EC2_LOCAL_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  serviceSubnet: ${SERVICE_CIDR}
  podSubnet: ${POD_CIDR}
  dnsDomain: ${DNS_DOMAIN}
EOF

    # API 버전 마이그레이션 시도
    log "kubeadm 구성 파일 마이그레이션 시도 중..."
    if kubeadm config migrate --old-config /tmp/kubeadm-config.yaml --new-config /tmp/new-kubeadm-config.yaml; then
        log "구성 파일 마이그레이션 성공, 새 구성 파일을 사용합니다."
        mv /tmp/new-kubeadm-config.yaml /tmp/kubeadm-config.yaml
    else
        log "구성 파일 마이그레이션 실패, 기존 구성 파일을 사용합니다."
    fi

    # 마스터 노드 초기화
    local retry_count=0
    local init_success=false
    while [ ${retry_count} -lt ${MAX_RETRIES} ]; do
        # 환경 변수 설정 (선택적)
        IPADDR=${EC2_LOCAL_IP}
        NODENAME=$(hostname -s)
        
        # kubeadm init 실행 (--ignore-preflight-errors=Swap 추가)
        if kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs --ignore-preflight-errors=Swap > /var/log/kubeadm_init.log 2>&1; then
            log "마스터 노드 초기화 성공"
            init_success=true
            break
        fi
        
        # 오류 로그 확인
        log "초기화 실패. 오류 로그:"
        cat /var/log/kubeadm_init.log
        
        retry_count=$((retry_count + 1))
        log "초기화 실패. ${RETRY_INTERVAL}초 후 재시도... (${retry_count}/${MAX_RETRIES})"
        sleep ${RETRY_INTERVAL}
    done

    # 초기화 실패 시 종료
    if [ "$init_success" = false ]; then
        log "마스터 노드 초기화 최종 실패"
        return 1
    fi

    # kubeconfig 설정
    mkdir -p $(dirname ${KUBECONFIG})
    cp -i ${K8S_CONFIG_DIR}/admin.conf ${KUBECONFIG}
    chown $(id -u ubuntu):$(id -g ubuntu) ${KUBECONFIG}

    # CNI 설치
    if ! install_cni; then
        log "CNI 설치 실패"
        return 1
    fi

    # Join 명령어 생성
    log "Join 명령어 생성 중..."
    kubeadm token create --print-join-command > /home/ubuntu/join_command
    chown ubuntu:ubuntu /home/ubuntu/join_command
    chmod 644 /home/ubuntu/join_command
    
    # Join 명령어 파일 생성 확인
    if [ ! -f /home/ubuntu/join_command ]; then
        log "Join 명령어 파일 생성 실패"
        return 1
    fi

    log "마스터 노드 초기화 완료"
    return 0
}


#################################################################
# ---------------- CNI 설치 섹션 ------------------
#################################################################

# CNI 디버깅 정보 수집
debug_cni() {
    log "CNI 디버깅 정보 수집"
    kubectl get pods -A
    kubectl get nodes -o wide
    kubectl describe nodes
    kubectl logs -n tigera-operator -l k8s-app=tigera-operator
    kubectl get installation -o yaml
}

# CNI 설치 검증
verify_cni() {
    log "CNI 설치 검증 시작"
    
    # calico-system 네임스페이스 생성 대기
    for i in $(seq 1 30); do
        if kubectl get ns calico-system >/dev/null 2>&1; then
            break
        fi
        log "calico-system 네임스페이스 대기 중... ${i}/30"
        sleep 10
    done
    
    # Pod 생성 대기
    if ! kubectl wait --for=condition=Ready pods --all -n calico-system --timeout=300s; then
        log "CNI POD 상태 확인"
        kubectl get pods -n calico-system
        kubectl describe pods -n calico-system
        log "CNI POD가 정상적으로 실행되지 않았습니다"
        return 1
    fi
    
    # 노드 네트워크 상태 확인
    if ! kubectl get nodes -o wide | grep -q "Ready"; then
        log "노드 네트워크 상태가 비정상입니다"
        kubectl describe nodes
        return 1
    fi
    
    log "CNI 설치 검증 완료"
    return 0
}

# CNI 롤백
rollback_cni() {
    log "CNI 설치 롤백 시작"
    kubectl delete -f custom-resources.yaml >/dev/null 2>&1 || true
    kubectl delete -f tigera-operator.yaml >/dev/null 2>&1 || true
    
    # 네임스페이스 삭제 확인
    for i in $(seq 1 10); do
        if ! kubectl get ns calico-system >/dev/null 2>&1; then
            break
        fi
        log "calico-system 네임스페이스 삭제 대기 중... ${i}/10"
        sleep 5
    done
    
    log "CNI 설치 롤백 완료"
}

# CNI 설치
install_cni() {
    log "Calico CNI 설치 시작"

    # 기존 CNI 설정 제거
    rollback_cni

    # 작업 디렉토리 생성
    mkdir -p ~/calico && cd ~/calico

    # Tigera Operator 설치
    log "Tigera Operator 설치"
    curl -LO ${CNI_MANIFEST}
    kubectl create -f tigera-operator.yaml

    # Operator 설치 대기
    log "Tigera Operator 초기화 대기 중..."
    sleep 20

    # Custom Resources 설치
    log "Calico Custom Resources 설치"
    curl -LO ${CNI_MANIFEST_CUSTOM}
    sed -i "s|cidr: .*|cidr: ${POD_CIDR}|g" custom-resources.yaml
    kubectl create -f custom-resources.yaml

    # 설치 후 초기화 대기
    log "Calico 구성요소 초기화 대기 중..."
    sleep 30

    # CNI 설치 확인
    local retry_count=0
    while [ ${retry_count} -lt ${MAX_RETRIES} ]; do
        log "CNI 설치 상태 확인... (${retry_count}/${MAX_RETRIES})"
        
        # 현재 상태 출력
        kubectl get pods -A | grep -E "calico-system|tigera-operator"
        
        if verify_cni; then
            log "Calico CNI 설치 및 검증 완료"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        
        if [ ${retry_count} -eq ${MAX_RETRIES} ]; then
            log "설치 실패 - 디버깅 정보 수집"
            debug_cni
        fi
        
        sleep ${WAIT_INTERVAL}
    done

    log "Calico CNI 설치 실패"
    rollback_cni
    return 1
}

#################################################################
# ---------------- Join 명령어 생성 섹션 ------------------
#################################################################

generate_join_command() {
    log "Join 명령어 생성 시작"
    
    # join 명령어 생성
    local join_command=$(kubeadm token create --print-join-command)
    echo "${join_command}" > /home/ubuntu/join_command
    
    # 파일 권한 설정
    chown ubuntu:ubuntu /home/ubuntu/join_command
    chmod 644 /home/ubuntu/join_command
    
    # 파일 생성 확인
    if [ ! -f /home/ubuntu/join_command ]; then
        log "Join 명령어 파일 생성 실패"
        return 1
    fi
    
    log "Join 명령어 생성 완료"
}

#################################################################
# ---------------- 메인 실행 섹션 ------------------
#################################################################

main() {
    log "설치 스크립트 시작"

    verify_system_requirements
    setup_network
    install_docker
    install_kubernetes

    if [[ "${NODE_ROLE}" == "master" ]]; then
        initialize_master
        generate_join_command
    fi

    log "설치 스크립트 완료"
}

# 스크립트 실행
main