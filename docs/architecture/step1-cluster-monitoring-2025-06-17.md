# Step 1: Kubernetes 클러스터 기본 모니터링 구현

**작업 날짜**: 2025년 6월 17일  
**작업 시간**: 약 45분  
**난이도**: ⭐⭐⭐  
**담당자**: DevOps Engineer

---

## 🎯 **목표 및 배경**

Self-managed Kubernetes 클러스터에서 **관찰가능성(Observability) 플랫폼의 기반**을 구축하기 위해 클러스터 레벨의 메트릭 수집 및 모니터링 시스템을 구현합니다.

### **비즈니스 요구사항**
- 클러스터 노드 및 Pod의 리소스 사용률 실시간 모니터링
- 시스템 장애 조기 탐지 및 성능 최적화를 위한 기반 구축
- DevOps 팀의 운영 효율성 향상

---

## 🏗️ **아키텍처 설계**

### **기술 스택 선택**
| 컴포넌트 | 선택 기술 | 선택 이유 |
|----------|-----------|-----------|
| **메트릭 수집** | Prometheus | 업계 표준, Pull 기반 아키텍처, PromQL 지원 |
| **시각화** | Grafana | 강력한 대시보드, 다양한 데이터 소스 지원 |
| **노드 메트릭** | Node Exporter | 시스템 레벨 메트릭 수집 표준 |
| **K8s 메트릭** | Kube State Metrics | Kubernetes 리소스 상태 메트릭 |
| **알림 관리** | AlertManager | Prometheus 네이티브 알림 시스템 |

### **배포 전략**
```mermaid
graph TB
    A[Self-managed K8s Cluster] --> B[monitoring namespace]
    B --> C[Prometheus Operator]
    C --> D[Prometheus Server]
    C --> E[Grafana]
    C --> F[AlertManager]
    
    G[Node Exporter DaemonSet] --> D
    H[Kube State Metrics] --> D
    I[Service Monitors] --> D
```

---

## 🛠️ **구현 과정**

### **Phase 1: 초기 접근 (metrics-server)**

**시도한 방법:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**발생한 문제:**
```bash
Error: dial tcp 10.0.2.99:10250: i/o timeout
```

**근본 원인 분석:**
- Self-managed 클러스터에서 kubelet 인증서 검증 실패
- Private subnet의 워커노드에서 TLS 인증 문제
- `kubectl top` 명령어 사용 불가

**해결 시도:**
```bash
# TLS 검증 우회 설정
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 주소 타입 명시
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}]'
```

**결과**: APIService 등록 실패로 인한 Metrics API 접근 불가

---

### **Phase 2: 전략 변경 (Prometheus Stack)**

**의사결정 배경:**
1. **production-ready**: 실무에서 검증된 안정적인 솔루션 필요
2. **통합 모니터링**: 단순 메트릭 수집을 넘어 완전한 관찰가능성 구현
3. **확장성**: 향후 서비스 메시 연동을 위한 기반 구축

**Helm 기반 배포 전략:**
```bash
# Helm 설치
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -L -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Prometheus Community 차트 저장소 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 전용 네임스페이스 생성
kubectl create namespace monitoring
```

**핵심 배포 명령어:**
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

**설정 최적화 포인트:**
- `serviceMonitorSelectorNilUsesHelmValues=false`: 모든 ServiceMonitor 자동 감지
- `podMonitorSelectorNilUsesHelmValues=false`: 모든 PodMonitor 자동 감지

---

## 📊 **구현 결과**

### **배포된 컴포넌트**
```bash
kubectl --namespace monitoring get pods
```
```
NAME                                                     READY   STATUS
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running
prometheus-grafana-99ccb774-m565p                        3/3     Running
prometheus-kube-prometheus-operator-77c56db4cb-b4pts     1/1     Running
prometheus-kube-state-metrics-dbbffb85b-sgcwp            1/1     Running
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running
prometheus-prometheus-node-exporter-jmttj                1/1     Running (master)
prometheus-prometheus-node-exporter-rl989                1/1     Running (worker-1)
prometheus-prometheus-node-exporter-vmqvc                1/1     Running (worker-2)
```

### **메트릭 수집 현황**
- **Node Exporter**: 3개 노드에서 시스템 메트릭 수집 중
- **Kube State Metrics**: Kubernetes 리소스 상태 메트릭 수집 중
- **Prometheus**: 메트릭 스크래핑 및 저장 정상 동작
- **AlertManager**: 알림 규칙 및 라우팅 준비 완료

### **접근 정보**
```bash
# Grafana 관리자 비밀번호 확인
kubectl --namespace monitoring get secrets prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
# 결과: prom-operator
```

---

## 🔍 **기술적 인사이트**

### **Self-managed vs Managed 환경 차이점**
1. **TLS 인증**: EKS/GKE와 달리 자체 구축 환경에서는 kubelet 인증서 관리 필요
2. **네트워킹**: Private subnet 환경에서의 Pod 간 통신 고려사항
3. **권한 관리**: RBAC 설정 및 ServiceAccount 권한 세밀한 조정 필요

### **Helm을 통한 Infrastructure as Code**
- **버전 관리**: 차트 버전을 통한 일관된 배포
- **설정 관리**: values.yaml을 통한 환경별 설정 분리
- **롤백 지원**: `helm rollback` 을 통한 안전한 배포 관리

### **Prometheus Operator 패턴의 장점**
1. **선언적 구성**: ServiceMonitor/PodMonitor CRD를 통한 설정
2. **자동 발견**: 라벨 셀렉터 기반 타겟 자동 등록
3. **설정 관리**: ConfigMap 대신 CR을 통한 중앙 집중화

---

## 📈 **성능 및 리소스 사용량**

### **리소스 요구사항**
| 컴포넌트 | CPU Request | Memory Request | 저장소 |
|----------|-------------|----------------|---------|
| Prometheus | 200m | 400Mi | 50Gi (기본) |
| Grafana | 100m | 128Mi | - |
| AlertManager | 100m | 128Mi | 2Gi |
| Node Exporter | 100m | 30Mi | - |

### **확장성 고려사항**
- **메트릭 보존**: 기본 15일, 운영 환경에서는 30-90일 권장
- **샤딩**: 대규모 환경에서 Prometheus 샤딩 전략 필요
- **페더레이션**: 멀티 클러스터 환경에서의 메트릭 집계 방안

---

## 🎯 **다음 단계 준비사항**

### **Step 2 준비: 데모 애플리케이션 배포**
1. **메트릭 생성**: 실제 워크로드를 통한 애플리케이션 메트릭 수집
2. **서비스 메시 준비**: Linkerd 주입을 위한 애플리케이션 구조 고려
3. **트래픽 패턴**: 부하 테스트를 통한 메트릭 시뮬레이션

### **기술 부채 관리**
- [ ] Grafana 대시보드 커스터마이징
- [ ] AlertManager 규칙 정의
- [ ] Prometheus 설정 최적화
- [ ] 보안 설정 강화 (TLS, 인증)

---

## 💡 **학습 포인트**

1. **문제 해결 과정**: 초기 접근 실패 → 원인 분석 → 전략 변경 → 성공
2. **기술 선택 기준**: 안정성 > 복잡성, Production-ready 솔루션 우선
3. **운영 관점**: 단순 모니터링을 넘어 통합 관찰가능성 구현의 중요성

**이 경험을 통해 Self-managed Kubernetes 환경에서의 모니터링 구축 전문성을 확보했습니다.** 