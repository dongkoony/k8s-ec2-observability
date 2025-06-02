#!/bin/bash

# 공통 부트스트랩 스크립트 실행
source "$(dirname "$0")/common-bootstrap.sh"

#################################################################
# ---------------- 변수 설정 섹션 ------------------
#################################################################

# 기본 변수 설정
MASTER_IP="$1"
NODE_INDEX="$2"

#################################################################
# ---------------- 노드 역할 설정 섹션 ------------------
#################################################################

# 노드 역할 및 마스터 IP 설정
export NODE_ROLE="worker-node${NODE_INDEX}"
export MASTER_PRIVATE_IP="${MASTER_IP}"

#################################################################
# ---------------- SSH 보안 설정 섹션 ------------------
#################################################################

# SSH 키 권한 설정
sudo chmod 400 ${SSH_KEY_PATH}

# SSH 보안 설정
touch /home/ubuntu/.ssh/known_hosts
echo 'StrictHostKeyChecking no' > /home/ubuntu/.ssh/config
chmod 600 /home/ubuntu/.ssh/config
ssh-keyscan -p 22 ${MASTER_IP} 2>/dev/null >> /home/ubuntu/.ssh/known_hosts

#################################################################
# ---------------- 클러스터 조인 섹션 ------------------
#################################################################

# 조인 명령어 대기 및 실행
until ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} 'test -f /home/ubuntu/join_command'; do 
    sleep 10
done

JOIN_CMD=$(ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} 'cat /home/ubuntu/join_command')
sudo $JOIN_CMD

#################################################################
# ---------------- 노드 레이블 설정 섹션 ------------------
#################################################################

# 노드 조인 완료 대기
sleep 30

# kubeconfig 설정
mkdir -p /home/ubuntu/.kube
ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} 'sudo cat /etc/kubernetes/admin.conf' > /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# 노드 레이블 설정
NODE_IP=$(hostname -I | awk '{print $1}')
FORMATTED_IP=$(echo $NODE_IP | tr '.' '-')
ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} "kubectl label node ip-${FORMATTED_IP} node-role.kubernetes.io/worker-node${NODE_INDEX}=''"

#################################################################
# ---------------- 완료 확인 섹션 ------------------
#################################################################

# 설정 완료 로그
echo "Worker node ${NODE_INDEX} setup completed successfully"