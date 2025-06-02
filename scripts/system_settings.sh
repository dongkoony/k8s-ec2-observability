#!/bin/bash

#################################################################
# ---------------- 환경 변수 설정 섹션 ------------------
#################################################################

# 시스템 설정
TIMEZONE="Asia/Seoul"
SSH_PORT="22"
SSH_CONFIG="/etc/ssh/sshd_config"

# 로그 설정
LOG_FILE="/home/ubuntu/system_settings.log"
LOG_PREFIX="[SYSTEM-SETUP]"

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

#################################################################
# ---------------- 시스템 설정 섹션 ------------------
#################################################################

# 로그 파일 초기화
> "${LOG_FILE}"

log "시스템 기본 설정 시작"

# 시간대 설정
log "시간대 설정 중..."
timedatectl set-timezone ${TIMEZONE}
check_error "시간대 설정 실패"

# SSH 포트 변경
log "SSH 포트 변경 중..."
sed -i "s/#Port 22/Port ${SSH_PORT}/g" ${SSH_CONFIG}
# hosts.allow 설정
sudo sh -c 'echo \"sshd: 10.0.0.0/16\" >> /etc/hosts.allow'
# hosts.deny 설정
sudo sh -c 'echo \"sshd: ALL\" >> /etc/hosts.deny'
# sshd 재시작
sudo systemctl restart sshd
check_error "SSH 설정 변경 실패"

# Swap 비활성화
log "Swap 비활성화 중..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
check_error "Swap 비활성화 실패"

# 방화벽 설정
log "방화벽 포트 추가 중..."
ufw allow ${SSH_PORT}/tcp
ufw allow 6443/tcp  # Kubernetes API Server
ufw allow 10250/tcp # Kubelet API
ufw allow 10251/tcp # kube-scheduler
ufw allow 10252/tcp # kube-controller-manager
ufw allow 65535/tcp
ufw allow 65535/udp

log "시스템 기본 설정 완료"

# 설정 완료 표시
touch /home/ubuntu/.system_settings_complete