# 📊 Grafana 대시보드 설정

## 📂 디렉토리 개요

Step 8 실전 운영 자동화를 위한 Grafana 대시보드 설정 파일들이 포함된 디렉토리입니다.

## 📈 포함된 대시보드

### `k8s-cluster-dashboard.json`
**Step 8 실시간 운영 대시보드 (t3.medium 환경 특화)**

**주요 특징:**
- 🖥️ t3.medium 마스터노드 리소스 모니터링
- 🏗️ 자체 관리형 Kubernetes 클러스터 상태
- 🔗 Linkerd 서비스 메시 메트릭
- 📱 Bookinfo 애플리케이션 성능
- 🚦 Pod 상태 실시간 추적

**8개 핵심 패널:**
1. **🖥️ 마스터노드 CPU 사용률** - 게이지 (70%/90% 임계값)
2. **💾 마스터노드 메모리 사용률** - 게이지 (60%/85% 임계값) 
3. **🏗️ 클러스터 노드 상태** - 상태표시 (3노드 상태)
4. **🚀 실행 중인 Pod 수** - 상태표시 (20/30 임계값)
5. **📊 Prometheus 요청 처리율** - 시계열
6. **🏷️ 네임스페이스별 Pod 분포** - 파이차트
7. **🌐 마스터노드 네트워크 I/O** - 시계열 
8. **🚦 Pod 상태 개요** - 테이블 (Running/Pending/Failed)

## 🚀 사용 방법

### 1. Grafana 접속
```bash
# Grafana UI 접속 (NodePort 30300)
http://<마스터-노드-IP>:30300

# 기본 로그인 정보
Username: admin
Password: prom-operator
```

### 2. 대시보드 임포트
1. Grafana 왼쪽 메뉴에서 **"+"** 클릭
2. **"Import"** 선택
3. **"Upload JSON file"** 클릭
4. `k8s-cluster-dashboard.json` 파일 선택
5. **"Import"** 버튼 클릭

### 3. 데이터 소스 확인
```bash
# Prometheus가 정상적으로 연결되었는지 확인
Data Sources → Prometheus → Test

# 예상 URL: http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090
```

## 📊 모니터링 임계값

### 🚨 Critical 알림 (빨간색)
- **CPU 사용률**: 90% 초과
- **메모리 사용률**: 85% 초과
- **노드 다운**: 1개 이상

### ⚠️ Warning 알림 (노란색)
- **CPU 사용률**: 70% 초과
- **메모리 사용률**: 60% 초과
- **Pod 수**: 20개 미만

### ✅ 정상 상태 (초록색)
- **모든 노드**: Ready 상태
- **Pod**: 30개 이상 Running
- **리소스**: 임계값 미만

## 🔧 대시보드 커스터마이징

### 마스터노드 IP 변경
```bash
# 대시보드 JSON에서 다음 부분 수정
"instance=~\".*ip-10-0-1-34.*\""
↓
"instance=~\".*your-master-hostname.*\""
```

### 새로운 패널 추가
1. 대시보드 편집 모드 진입
2. **"Add panel"** 클릭
3. 원하는 메트릭 쿼리 작성
4. 시각화 타입 선택
5. **"Apply"** 및 **"Save"** 클릭

## 🔗 관련 문서

- [커스텀 알림 규칙](../observability/custom-alert-rules.yaml)
- [자동화 스크립트](../../scripts/automation/README.md)
- [Prometheus 설정](../observability/prometheus-stack-values.yml) 