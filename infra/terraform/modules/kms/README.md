# AWS KMS Module

이 모듈은 k8s-ec2-observability 프로젝트를 위한 AWS KMS(Key Management Service) 리소스를 관리합니다.

## 아키텍처 설계 결정

### CloudWatch/CloudTrail 통합 설계

이 모듈은 KMS 키 관리뿐만 아니라 CloudWatch 모니터링과 CloudTrail 감사 기능을 포함하고 있습니다. 이러한 설계 결정의 이유는 다음과 같습니다:

1. 보안 중심 설계
   - KMS는 보안 핵심 서비스로, 모니터링과 감사가 필수적
   - 키 생성, 삭제, 사용 등 모든 작업의 실시간 모니터링 필요
   - 보안 감사 및 규정 준수를 위한 상세한 활동 로그 필요

2. 운영 효율성
   - 키 관리와 모니터링이 단일 모듈에서 통합 관리됨
   - 문제 발생 시 빠른 탐지와 대응 가능
   - 설정 변경과 트러블슈팅이 용이

3. 현재 프로젝트 상황
   - 단일 KMS 모듈에 특화된 모니터링/감사 요구사항
   - 다른 서비스와의 모니터링 통합 필요성이 현재는 낮음
   - 빠른 개발과 안정적인 운영이 우선순위

### 향후 고려사항

프로젝트 규모가 커지고 다른 서비스에서도 유사한 모니터링/감사 요구사항이 생기면, 다음과 같은 모듈 분리를 고려할 수 있습니다:

- 모니터링 전용 모듈 분리
- 감사 로깅 전용 모듈 분리
- 공통 보안 설정 모듈 구성

## 기능

- KMS 키 생성 및 관리
- 자동 키 교체 설정
- 태그 관리
- IAM 정책 및 권한 설정
- 키 별칭 관리
- CloudWatch 모니터링
  - 키 사용량 메트릭
  - 상태 변경 경보
  - 자동 복구 트리거
- CloudTrail 감사
  - 모든 API 활동 로깅
  - S3 보관 및 암호화
  - 로그 보존 정책

## 사용 방법

```hcl
module "kms" {
  source = "./modules/kms"

  project_name           = "k8s-ec2-observability"
  environment           = "dev"
  enable_key_rotation   = true
  deletion_window_in_days = 7
  alias_name            = "alias/my-custom-key"  # 선택사항, 'alias/'로 시작해야 함

  # CloudWatch 설정
  log_retention_days    = 30
  key_usage_threshold   = 1000
  alarm_actions        = ["arn:aws:sns:region:account-id:topic-name"]

  # CloudTrail 설정
  enable_logging        = true
  include_management_events = true

  tags = {
    Team = "DevOps"
    Additional = "Tag"
  }
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|------|------|------|--------|-----------|
| project_name | 프로젝트 이름 | string | - | yes |
| environment | 배포 환경 (dev/stage/prod) | string | - | yes |
| enable_key_rotation | 키 자동 교체 활성화 여부 | bool | true | no |
| deletion_window_in_days | 삭제 대기 기간 | number | 7 | no |
| alias_name | 키 별칭 | string | null | no |
| log_retention_days | CloudWatch 로그 보관 기간 | number | 30 | no |
| key_usage_threshold | 키 사용량 경보 임계값 | number | 1000 | no |
| alarm_actions | 경보 발생 시 실행할 작업 | list(string) | [] | no |
| enable_logging | CloudTrail 로깅 활성화 | bool | true | no |
| tags | 추가 태그 | map(string) | {} | no |

## 출력 변수

| 이름 | 설명 |
|------|------|
| key_id | 생성된 KMS 키의 ID |
| key_arn | 생성된 KMS 키의 ARN |
| alias_name | 생성된 KMS 키의 별칭 |
| cloudwatch_log_group_name | CloudWatch 로그 그룹 이름 |
| cloudtrail_name | CloudTrail 트레일 이름 |
| cloudwatch_alarm_name | 키 사용량 경보 이름 |

## 모니터링 및 경보

이 모듈은 다음과 같은 모니터링 기능을 제공합니다:

1. CloudWatch 메트릭
   - 키 사용량
   - API 호출 수
   - 오류 발생 수

2. CloudWatch 경보
   - 키 사용량 임계값 초과
   - 연속 오류 발생
   - 비정상 API 호출

3. CloudTrail 감사 로그
   - 모든 KMS API 호출
   - IAM 사용자/역할 식별
   - 요청/응답 세부 정보

## 보안 고려사항

1. 키 보호
   - 자동 교체 기본 활성화
   - 실수 삭제 방지
   - 프로덕션 환경 특별 보호

2. 접근 제어
   - 최소 권한 원칙 적용
   - IAM 정책 세분화
   - 서비스별 권한 구분

3. 감사
   - 모든 작업 로깅
   - 로그 암호화 저장
   - 장기 보관 정책

## 문제 해결

일반적인 문제 해결 방법:

1. 키 접근 오류
   - IAM 정책 확인
   - 키 상태 확인
   - CloudTrail 로그 분석

2. 모니터링 문제
   - CloudWatch 로그 확인
   - 경보 설정 검증
   - 메트릭 데이터 확인

3. 백업/복구
   - 자동 백업 상태 확인
   - 복구 절차 실행
   - 복제 상태 확인 