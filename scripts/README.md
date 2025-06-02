## Kubernetes 설치 스크립트 (combined_settings.sh)
[![EN](https://img.shields.io/badge/lang-en-blue.svg)](README-en.md) 
[![KR](https://img.shields.io/badge/lang-kr-red.svg)](README.md)

이 스크립트는 AWS EC2 인스턴스에 Kubernetes v1.31과 Calico CNI v3.28.0을 자동으로 설치하고 구성하는 통합 설정 스크립트입니다.

### 주요 구성 요소

#### 1. 환경 변수 설정
```bash
# Kubernetes 버전: v1.31.0
# Calico CNI 버전: v3.28.0
# Pod CIDR: 10.244.0.0/16
# Service CIDR: 10.96.0.0/12
```

#### 2. 시스템 요구사항
- 최소 CPU 코어: 2개
- 최소 메모리: 2GB
- 필수 포트: 6443, 10250, 10251, 10252, 2379, 2380

### 주요 기능

#### 1. 네트워크 설정
- 커널 모듈 설정 (overlay, br_netfilter)
- 시스템 네트워크 파라미터 구성
- Calico CNI 자동 설치 및 구성

#### 2. 컨테이너 런타임 설치
- Docker 설치 및 구성
- Containerd 설정 최적화
- SystemdCgroup 활성화

#### 3. Kubernetes 설치
- kubelet, kubeadm, kubectl 설치
- 버전 고정을 통한 안정성 확보
- 자동 버전 관리

#### 4. 마스터 노드 설정
- kubeadm을 통한 클러스터 초기화
- API 서버 엔드포인트 구성
- kubeconfig 자동 설정

#### 5. CNI 구성
- Calico CNI 자동 설치
- 네트워크 정책 설정
- Pod 네트워크 구성

### 사용 방법 (수동 설치)

1. **스크립트 실행 권한 설정**
```bash
chmod +x combined_settings.sh
```

2. **마스터 노드 설치**
```bash
export NODE_ROLE=master
sudo -E ./combined_settings.sh
```

3. **워커 노드 설치**
```bash
export NODE_ROLE=worker
export MASTER_PRIVATE_IP=<마스터_노드_IP>
sudo -E ./combined_settings.sh
```

### 주요 기능 설명

#### 자동 검증 및 오류 처리
- 시스템 요구사항 자동 검증
- 설치 과정 중 오류 발생 시 자동 롤백
- 상세한 로그 기록 (/home/ubuntu/combined_settings.log)

#### CNI 설치 및 검증
- Calico Operator 자동 설치
- CNI 구성 요소 상태 모니터링
- 네트워크 정책 자동 구성

#### 클러스터 조인 자동화
- 조인 토큰 자동 생성
- 워커 노드 자동 조인 설정
- 보안 설정 자동 구성

### 주의사항
1. 스크립트 실행 전 AWS EC2 인스턴스 요구사항 확인
2. 마스터 노드 설치 완료 후 워커 노드 설치 진행
3. 네트워크 보안 그룹에서 필요한 포트 개방 확인
4. 충분한 디스크 공간 확보 (최소 20GB 권장)

### 문제 해결
- 로그 파일 확인: `/home/ubuntu/combined_settings.log`
- CNI 상태 확인: `kubectl get pods -n calico-system`
- 노드 상태 확인: `kubectl get nodes`

이 스크립트는 Terraform을 통해 자동으로 실행되도록 설계되었으며, 수동 실행도 가능합니다.