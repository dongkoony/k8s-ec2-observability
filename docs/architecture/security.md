# 보안 아키텍처

## KMS (Key Management Service)

### 1. 키 구성

#### 1.1 KMS 키 기본 설정
- 대칭 암호화 키 (Symmetric)
- AWS 관리형 키 교체 (자동 교체 활성화)
- 삭제 대기 기간: 7-30일 (환경별 설정)
- 별칭: `alias/<project_name>-<environment>`

#### 1.2 태그 관리
```hcl
default_tags = {
  Name        = "${var.project_name}-kms-key"
  Environment = var.environment
  Project     = var.project_name
  Terraform   = "true"
  Team        = "DevOps"
}
```

### 2. 접근 제어

#### 2.1 키 정책
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow Key Administrators",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${account_id}:user/terraform-developer"
      },
      "Action": [
        "kms:Create*", "kms:Describe*", "kms:Enable*",
        "kms:List*", "kms:Put*", "kms:Update*",
        "kms:Revoke*", "kms:Disable*", "kms:Get*",
        "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow EC2 to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt", "kms:DescribeKey", "kms:Encrypt",
        "kms:ReEncrypt*", "kms:GenerateDataKey*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 2.2 IAM 역할 및 정책
1. terraform-developer
   - KMS 키 관리 권한
   - 태그 관리 권한
   - 키 정책 관리 권한

2. EC2 서비스
   - 암호화/복호화 권한
   - 키 설명 조회 권한
   - 데이터 키 생성 권한

### 3. 암호화 설정

#### 3.1 자동 키 교체
- 활성화: `enable_key_rotation = true`
- 교체 주기: 1년 (AWS 관리)
- 이전 키 버전 자동 보관

#### 3.2 키 삭제 보호
- 프로덕션 환경: `prevent_destroy = true`
- 삭제 대기 기간
  - 개발 환경: 7일
  - 스테이징 환경: 14일
  - 프로덕션 환경: 30일

### 4. 모니터링 및 감사

#### 4.1 CloudWatch 로그
- KMS 키 사용 로그
- 키 정책 변경 로그
- 태그 변경 로그

#### 4.2 CloudTrail 감사
- KMS API 호출 기록
- 키 사용 이벤트
- 정책 변경 이벤트

### 5. 보안 모범 사례

#### 5.1 키 관리
1. 키 교체
   - 자동 키 교체 활성화
   - 정기적인 키 상태 확인
   - 교체 이벤트 모니터링

2. 접근 제어
   - 최소 권한 원칙 적용
   - 정기적인 권한 검토
   - 미사용 권한 제거

3. 태그 관리
   - 필수 태그 적용
   - 태그 기반 접근 제어
   - 정기적인 태그 감사

#### 5.2 운영 보안
1. 변경 관리
   - Terraform 코드 리뷰
   - 변경 사항 문서화
   - 롤백 계획 수립

2. 인시던트 대응
   - 키 노출 대응 절차
   - 비상 연락망 유지
   - 정기적인 훈련

3. 규정 준수
   - 정기적인 감사
   - 컴플라이언스 요구사항 검토
   - 문서화된 증거 유지

### 6. 재해 복구

#### 6.1 백업 및 복구
1. 키 백업
   - AWS 관리형 백업
   - 다중 리전 복제 (선택사항)
   - 백업 상태 모니터링

2. 복구 절차
   - 키 복구 프로세스
   - 권한 복구 절차
   - 태그 복구 확인

#### 6.2 비상 계획
1. 키 손상 대응
   - 즉시 키 비활성화
   - 새 키 생성 및 교체
   - 영향 평가 및 보고

2. 서비스 연속성
   - 대체 키 준비
   - 자동화된 복구 스크립트
   - 정기적인 DR 테스트

### 7. 문서화 및 교육

#### 7.1 문서화
1. 기술 문서
   - 아키텍처 다이어그램
   - 구성 가이드
   - 운영 매뉴얼

2. 보안 문서
   - 보안 정책
   - 절차 가이드
   - 감사 보고서

#### 7.2 교육
1. 개발자 교육
   - KMS 사용 가이드
   - 보안 모범 사례
   - 인시던트 대응

2. 운영자 교육
   - 키 관리 절차
   - 모니터링 가이드
   - 문제 해결 방법

## 보안 모범 사례

1. 키 사용
   - 용도별 키 분리
   - 환경별 키 분리
   - 자동 키 교체 활성화

2. 접근 제어
   - 세분화된 권한 정책
   - 서비스별 최소 권한
   - 명시적 거부 정책

3. 문서화
   - 설정 문서화
   - 테스트 절차
   - 변수 검증

## 규정 준수

1. 암호화 요구사항
   - FIPS 140-2
   - PCI DSS
   - HIPAA

2. 감사 요구사항
   - 활동 기록
   - 변경 이력
   - 접근 로그

3. 보고 요구사항
   - 월간 보안 보고서
   - 인시던트 보고
   - 규정 준수 증빙 