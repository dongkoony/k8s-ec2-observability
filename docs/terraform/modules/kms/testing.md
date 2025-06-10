# KMS 모듈 테스트 가이드

## 테스트 환경 요구사항

1. Go 환경
   - Go 1.16 이상
   - `go.mod` 파일이 있는 디렉토리에서 실행

2. AWS 자격 증명
   - AWS IAM 사용자 필요
   - 필요한 권한:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "kms:CreateKey",
             "kms:DescribeKey",
             "kms:ListKeys",
             "kms:TagResource",
             "kms:UntagResource",
             "kms:EnableKeyRotation",
             "kms:GetKeyRotationStatus",
             "kms:ScheduleKeyDeletion",
             "kms:CreateAlias",
             "kms:DeleteAlias"
           ],
           "Resource": "*"
         }
       ]
     }
     ```

3. 환경 변수 설정
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="ap-northeast-2"
```

## 테스트 실행

### 전체 테스트 실행
```bash
cd test/unit/kms
go test -v ./...
```

### 개별 테스트 실행
```bash
# 키 생성 테스트
go test -v -run TestKMSKeyCreation

# 키 교체 테스트
go test -v -run TestKMSKeyRotation

# 태그 테스트
go test -v -run TestKMSKeyTags
```

## 테스트 케이스 상세

### TestKMSKeyCreation
```go
func TestKMSKeyCreation(t *testing.T) {
    // 테스트 설정
    config := helpers.NewKMSTestConfig()
    
    // 검증 항목:
    // 1. KMS 키 생성
    // 2. 기본 설정 적용
    // 3. 키 별칭 생성
    // 4. 리소스 정리
}
```

### TestKMSKeyRotation
```go
func TestKMSKeyRotation(t *testing.T) {
    // 테스트 설정
    config := helpers.NewKMSTestConfig()
    config.EnableKeyRotation = true
    
    // 검증 항목:
    // 1. 키 자동 교체 활성화
    // 2. AWS 관리형 교체 설정
}
```

### TestKMSKeyTags
```go
func TestKMSKeyTags(t *testing.T) {
    // 테스트 설정
    config := helpers.NewKMSTestConfig()
    config.CustomTags = map[string]string{
        "Team": "DevOps"
    }
    
    // 검증 항목:
    // 1. 기본 태그 설정
    // 2. 사용자 정의 태그 적용
    // 3. 태그 병합 확인
}
```

## 테스트 헬퍼 함수

### NewKMSTestConfig
```go
type KMSTestConfig struct {
    ProjectName       string
    Environment      string
    EnableKeyRotation bool
    CustomTags       map[string]string
}

func NewKMSTestConfig() *KMSTestConfig {
    return &KMSTestConfig{
        ProjectName:       "k8s-ec2-observability",
        Environment:      "test",
        EnableKeyRotation: true,
        CustomTags:       make(map[string]string),
    }
}
```

### SetupKMSTest
```go
func SetupKMSTest(t *testing.T, config *KMSTestConfig) (*terraform.Options, func()) {
    // 1. 임시 디렉토리 생성
    // 2. Terraform 설정 초기화
    // 3. 정리 함수 반환
}
```

## 문제 해결

### 일반적인 문제

1. 자격 증명 오류
```
AWS credentials not found
```
- 환경 변수가 올바르게 설정되었는지 확인
- AWS 자격 증명 권한 확인

2. 권한 부족
```
AccessDenied: User is not authorized to perform kms:CreateKey
```
- IAM 정책에 필요한 권한이 모두 포함되어 있는지 확인
- AWS 계정의 KMS 키 생성 제한 확인

3. 리소스 정리 실패
```
Error destroying resources
```
- AWS 콘솔에서 수동 확인
- 리소스 의존성 확인
- 수동 정리 필요시 순서:
  1. KMS 별칭 삭제
  2. KMS 키 비활성화
  3. KMS 키 삭제 예약

## 테스트 모범 사례

1. 격리된 환경
   - 테스트용 별도 AWS 계정 사용
   - 테스트 환경 분리
   - 고유한 리소스 이름 사용

2. 리소스 정리
   - defer를 사용한 정리 보장
   - 테스트 실패 시에도 정리 수행
   - 리소스 존재 여부 확인 후 정리

3. 명확한 오류 메시지
   - 구체적인 실패 원인 명시
   - 예상값과 실제값 비교 제공
   - 문제 해결 방법 제시 