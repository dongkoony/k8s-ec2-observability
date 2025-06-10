package kms

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// KMS 키 생성 테스트
func TestKMSKeyCreation(t *testing.T) {
	t.Parallel()

	t.Logf("🔐 KMS 키 생성 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// KMS 키 생성
	t.Logf("🚀 KMS 키 및 관련 리소스 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 유효성 검증
	t.Logf("🔍 KMS 키 유효성 검증 중...")
	keyID, keyArn := helpers.ValidateKMSKeyOutput(t, awsClient, terraformOptions)
	key, err := awsClient.ValidateKMSKey(keyID)
	assert.NoError(t, err)
	assert.Equal(t, keyArn, *key.KeyMetadata.Arn)

	t.Logf("✅ KMS 키 생성 테스트 완료: %s", keyID)
}
