package kms

import (
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// KMS 키 생성 테스트 (GitHub Actions 최적화)
func TestKMSKeyCreation(t *testing.T) {
	// t.Parallel() 제거 - AWS API 제한 방지를 위해 순차 실행

	t.Logf("🔐 KMS 키 생성 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer func() {
		t.Logf("🧹 KMS 리소스 정리 중...")
		terraform.Destroy(t, terraformOptions)
		t.Logf("✅ KMS 리소스 정리 완료")
	}()

	// KMS 키 생성
	t.Logf("🚀 KMS 키 생성 중... (단순화된 설정)")
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 기본 검증
	t.Logf("🔍 KMS 키 기본 검증 중...")
	keyID := terraform.Output(t, terraformOptions, "key_id")
	keyArn := terraform.Output(t, terraformOptions, "key_arn")

	// 기본 출력값 검증
	assert.NotEmpty(t, keyID, "KMS 키 ID가 비어있지 않아야 합니다")
	assert.NotEmpty(t, keyArn, "KMS 키 ARN이 비어있지 않아야 합니다")
	assert.Contains(t, keyArn, keyID, "ARN에 키 ID가 포함되어야 합니다")

	// KMS 키 상태 검증 (재시도 로직 포함)
	t.Logf("🔍 KMS 키 상태 검증 중...")
	var key *kms.DescribeKeyOutput
	var err error

	// 최대 3번 재시도 (AWS 전파 시간 고려)
	for i := 0; i < 3; i++ {
		key, err = awsClient.ValidateKMSKey(keyID)
		if err == nil && key != nil {
			break
		}
		if i < 2 {
			t.Logf("⏳ KMS 키 상태 확인 재시도 중... (%d/3)", i+1)
			time.Sleep(10 * time.Second)
		}
	}

	assert.NoError(t, err, "KMS 키 조회에 실패하지 않아야 합니다")
	assert.NotNil(t, key, "KMS 키가 존재해야 합니다")

	if key != nil && key.KeyMetadata != nil {
		assert.Equal(t, "Enabled", *key.KeyMetadata.KeyState, "KMS 키가 활성화 상태여야 합니다")
		assert.Equal(t, "ENCRYPT_DECRYPT", *key.KeyMetadata.KeyUsage, "KMS 키가 암호화/복호화 용도여야 합니다")
		assert.Equal(t, keyArn, *key.KeyMetadata.Arn, "ARN이 일치해야 합니다")
	}

	t.Logf("✅ KMS 키 생성 테스트 완료: %s", keyID)
}
