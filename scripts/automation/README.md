### 1. `auto-recovery-system-fixed.sh`
**개선된 자동복구 시스템 (DRY RUN 지원)**

```bash
# DRY RUN 모드로 테스트
./auto-recovery-system-fixed.sh --dry-run

# 실제 복구 실행
./auto-recovery-system-fixed.sh
```

**주요 기능:**
- OOMKilled Pod 자동 감지 및 재시작
- Pending Pod 리소스 최적화
- Linkerd 상태 검사 및 복구
- 모니터링 스택 헬스체크
- 시스템 상태 보고서 생성
- DRY RUN 모드 지원

### 2. `auto-recovery-system.sh`
**기본 자동복구 시스템 (연속 실행 모드)**

```bash
# 연속 모니터링 및 자동복구 시작
./auto-recovery-system.sh run

# 1회성 테스트 실행
./auto-recovery-system.sh test
```

**주요 기능:**
- 30초 간격 연속 모니터링
- 마스터노드 강제 배치 최적화
- Linkerd 프록시 주입 상태 관리
- 실시간 메트릭 수집

## 사용 시나리오

### 테스트 환경
```bash
# 1. DRY RUN으로 안전 테스트
cd scripts/automation
./auto-recovery-system-fixed.sh --dry-run

# 2. 1회성 복구 실행
./auto-recovery-system.sh test
```

### 프로덕션 환경
```bash
# 1. 즉시 복구 실행
./auto-recovery-system-fixed.sh

# 2. 연속 모니터링 시작 (백그라운드)
nohup ./auto-recovery-system.sh run > /tmp/auto-recovery.log 2>&1 &
```

## 로그 관리

### 로그 파일 위치
- **Fixed 버전**: `/tmp/auto-recovery-YYYYMMDD.log`
- **기본 버전**: `/tmp/auto-recovery.log`

### 로그 모니터링
```bash
# 실시간 로그 확인
tail -f /tmp/auto-recovery-$(date +%Y%m%d).log

# 특정 이벤트 검색
grep "🚨\|❌\|⚠️" /tmp/auto-recovery-*.log
```

## ⚙️ 설정 사용자화

### 마스터노드 IP 변경
```bash
# 스크립트 상단의 MASTER_NODE 변수 수정
MASTER_NODE="your-master-node-hostname"
```

### 체크 간격 조정
```bash
# CHECK_INTERVAL 변수 수정 (초 단위)
CHECK_INTERVAL=60  # 1분 간격
```

## 🔗 관련 문서

- [Step 8 아키텍처 문서](../../docs/architecture/step8-operational-automation-2025-07-04.md)
- [커스텀 알림 규칙](../../manifests/observability/custom-alert-rules.yaml)
- [Grafana 대시보드](../../manifests/grafana/)
- [프로젝트 메인 문서](../../README.md) 