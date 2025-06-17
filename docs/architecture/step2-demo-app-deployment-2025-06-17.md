# Step 2: 마이크로서비스 데모 애플리케이션 배포

**작업 날짜**: 2025년 6월 17일  
**작업 시간**: 약 15분  
**난이도**: ⭐⭐  
**담당자**: DevOps Engineer

---

## 🎯 **목표 및 배경**

관찰가능성 플랫폼의 **실제 워크로드 대상**을 확보하기 위해 프로덕션 환경과 유사한 마이크로서비스 아키텍처를 구현합니다. Istio의 Bookinfo 샘플 애플리케이션을 활용하여 서비스 간 통신, 로드 밸런싱, 트래픽 관리 시나리오를 제공합니다.

### **비즈니스 요구사항**
- 실제 마이크로서비스 환경에서의 관찰가능성 검증
- 서비스 메시 도입 전 baseline 성능 측정
- 분산 시스템의 복잡성을 반영한 모니터링 시나리오 구성

---

## 🏗️ **아키텍처 설계**

### **선택된 애플리케이션: Istio Bookinfo**
| 서비스 | 언어/프레임워크 | 포트 | 역할 |
|---------|----------------|------|------|
| **productpage** | Python/Flask | 9080 | 프론트엔드 웹 인터페이스 |
| **details** | Ruby/Sinatra | 9080 | 책 세부정보 API |
| **ratings** | Node.js/Express | 9080 | 평점 정보 API |
| **reviews** | Java/Liberty | 9080 | 리뷰 정보 API (3개 버전) |

### **마이크로서비스 토폴로지**
```mermaid
graph TD
    A[User] --> B[productpage:30080]
    B --> C[details:9080]
    B --> D[reviews:9080]
    D --> E[ratings:9080]
    
    F[reviews-v1] --> G[No ratings]
    H[reviews-v2] --> I[★ Black stars]  
    J[reviews-v3] --> K[★ Red stars]
    
    D --> F
    D --> H  
    D --> J
    H --> E
    J --> E
```

### **선택 이유**
1. **다중 언어 환경**: Python, Ruby, Node.js, Java로 실제 환경 반영
2. **서비스 의존성**: 계층적 서비스 호출 패턴
3. **A/B 테스팅**: reviews 서비스의 3개 버전으로 카나리 배포 시뮬레이션
4. **실제 트래픽**: HTTP 요청/응답 패턴으로 메트릭 생성

---

## 🛠️ **구현 과정**

### **Phase 1: 네임스페이스 및 리소스 준비**

**전용 네임스페이스 생성:**
```bash
kubectl create namespace bookinfo
```

**매니페스트 다운로드:**
```bash
curl -L https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml -o bookinfo.yaml
```

### **Phase 2: 마이크로서비스 배포**

**애플리케이션 배포:**
```bash
kubectl apply -f bookinfo.yaml -n bookinfo
```

**배포된 리소스:**
```yaml
# 서비스 계정 (각 마이크로서비스별)
- bookinfo-details
- bookinfo-ratings  
- bookinfo-reviews
- bookinfo-productpage

# 서비스 (ClusterIP)
- details:9080
- ratings:9080
- reviews:9080  
- productpage:9080

# 디플로이먼트
- details-v1 (1 replica)
- ratings-v1 (1 replica)
- reviews-v1 (1 replica) # 평점 기능 없는 버전
- reviews-v2 (1 replica) # 기본 별점 표시 버전
- reviews-v3 (1 replica) # 강조된 별점 표시 버전
- productpage-v1 (1 replica)
```

### **Phase 3: 외부 접근 설정**

**NodePort 서비스 설정:**
```bash
kubectl patch svc productpage -n bookinfo -p '{
  "spec": {
    "type": "NodePort",
    "ports": [{
      "port": 9080,
      "targetPort": 9080,
      "nodePort": 30080
    }]
  }
}'
```

**접근 포인트:**
- **내부 접근**: `http://productpage.bookinfo.svc.cluster.local:9080`
- **외부 접근**: `http://[NODE_IP]:30080/productpage`

---

## 📊 **배포 결과**

### **Pod 배포 상태**
```bash
kubectl get pods -n bookinfo
```
```
NAME                              READY   STATUS
details-v1-86545f5dfb-7n658       1/1     Running
productpage-v1-7c74cbdbcc-bxsbg   1/1     Running
ratings-v1-57544668d4-g6pdg       1/1     Running
reviews-v1-5f58978c56-l9bhq       1/1     Running  
reviews-v2-7bd564ffc6-v9jh6       1/1     Running
reviews-v3-7dfb7c4b64-v5gcw       1/1     Running
```

### **서비스 네트워킹**
```bash
kubectl get svc -n bookinfo
```
```
NAME          TYPE       CLUSTER-IP       PORT(S)
details       ClusterIP  10.105.31.154    9080/TCP
productpage   NodePort   10.103.108.218   9080:30080/TCP
ratings       ClusterIP  10.108.35.170    9080/TCP
reviews       ClusterIP  10.103.75.130    9080/TCP
```

### **리소스 사용량 분석**
| Pod | CPU Request | Memory Request | Node 배치 |
|-----|-------------|---------------|-----------|
| details-v1 | 100m | 64Mi | worker-node1 |
| productpage-v1 | 100m | 64Mi | worker-node2 |  
| ratings-v1 | 100m | 64Mi | worker-node1 |
| reviews-v1 | 100m | 64Mi | worker-node2 |
| reviews-v2 | 100m | 64Mi | worker-node1 |
| reviews-v3 | 100m | 64Mi | worker-node2 |

---

## 🔍 **기술적 인사이트**

### **마이크로서비스 설계 패턴**
1. **서비스별 언어 다양성**: 실제 조직의 polyglot 환경 반영
2. **버전 관리 전략**: reviews 서비스의 3개 버전으로 롤링 업데이트 시뮬레이션
3. **의존성 관리**: productpage → details/reviews → ratings 체인

### **Kubernetes 네이티브 패턴**
- **Service Discovery**: DNS 기반 서비스 간 통신
- **Load Balancing**: kube-proxy의 iptables 기반 로드 밸런싱
- **Health Checks**: 각 서비스의 liveness/readiness probe

### **관찰가능성 관점**
1. **메트릭 포인트**: 
   - HTTP 요청/응답 시간
   - 서비스 간 latency
   - 에러율 및 성공률
2. **로그 소스**:
   - 애플리케이션 로그 (stdout)
   - 액세스 로그 (nginx, 각 언어별)
3. **트레이싱 경로**:
   - productpage → details (직접 호출)
   - productpage → reviews → ratings (체인 호출)

---

## 🚀 **성능 벤치마크**

### **컨테이너 이미지 풀링 시간**
- **details**: ~15초 (Ruby 기반)
- **ratings**: ~20초 (Node.js 기반)  
- **reviews**: ~45초 (Java/Liberty 기반, 가장 큰 이미지)
- **productpage**: ~25초 (Python 기반)

### **서비스 시작 시간**
- **전체 애플리케이션 준비**: ~60초
- **health check 통과**: 배포 후 15초 이내
- **서비스 간 연결성 확립**: 즉시

### **네트워크 구성**
```bash
# 서비스 메시 없는 기본 성능
- productpage → details: ~2ms (같은 노드)
- productpage → reviews: ~3ms (다른 노드)  
- reviews → ratings: ~2ms (같은 노드)
```

---

## 🎯 **다음 단계 준비사항**

### **Step 3 준비: 트래픽 생성 및 모니터링**
1. **부하 테스트 도구**: hey, wrk, 또는 siege를 사용한 트래픽 시뮬레이션
2. **메트릭 수집**: Prometheus에서 애플리케이션 메트릭 스크래핑 확인
3. **대시보드 구성**: Grafana에서 서비스별 성능 대시보드 준비

### **서비스 메시 준비**
- [ ] Linkerd 주입을 위한 애플리케이션 annotation 준비
- [ ] mTLS 적용 전 baseline 성능 측정  
- [ ] 트래픽 정책 및 라우팅 규칙 설계

---

## 💡 **학습 포인트**

### **마이크로서비스 운영 복잡성**
1. **언어별 특성**: Java 애플리케이션의 긴 시작 시간 vs Node.js의 빠른 시작
2. **의존성 관리**: 서비스 시작 순서 및 health check 중요성
3. **네트워크 정책**: Pod-to-Pod 통신과 DNS 해석

### **Kubernetes 리소스 관리**
- **네임스페이스 분리**: 애플리케이션별 격리의 중요성
- **서비스 타입**: ClusterIP vs NodePort 선택 기준
- **레이블 셀렉터**: 서비스 발견 및 트래픽 라우팅

### **DevOps 모범 사례**
1. **선언적 배포**: YAML 매니페스트를 통한 Infrastructure as Code
2. **점진적 배포**: 여러 버전의 동시 운영으로 무중단 배포 준비
3. **관찰가능성 기반**: 메트릭 생성을 고려한 아키텍처 설계

**이 단계를 통해 실제 프로덕션 환경과 유사한 마이크로서비스 워크로드를 확보하고, 다음 관찰가능성 도구들의 실효성을 검증할 기반을 마련했습니다.** 