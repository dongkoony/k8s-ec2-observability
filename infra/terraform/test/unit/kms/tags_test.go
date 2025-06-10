package kms

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// TestKMSKeyTags KMS 키 태그 테스트
func TestKMSKeyTags(t *testing.T) {
	t.Parallel()

	t.Logf("🏷️ KMS 키 태그 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// KMS 키 생성
	t.Logf("🔐 KMS 키 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// 태그 검증을 위한 예상 태그 정의
	expectedTags := map[string]string{
		"Environment": "test",
		"Project":     "k8s-ec2-observability",
		"ManagedBy":   "terraform",
		"Team":        "DevOps",
		"Terraform":   "true",
		"Name":        "k8s-ec2-observability-kms-key",
	}

	// KMS 키 태그 검증
	t.Logf("🔍 KMS 키 태그 검증 중...")
	keyID, _ := helpers.ValidateKMSKeyOutput(t, awsClient, terraformOptions)
	actualTags, err := awsClient.GetKMSKeyTags(keyID)
	assert.NoError(t, err)

	// 모든 예상 태그가 존재하는지 확인
	for expectedKey, expectedValue := range expectedTags {
		actualValue, exists := actualTags[expectedKey]
		assert.True(t, exists, "태그 '%s'가 존재해야 합니다", expectedKey)
		assert.Equal(t, expectedValue, actualValue, "태그 '%s'의 값이 일치해야 합니다", expectedKey)
	}

	t.Logf("✅ KMS 키 태그 테스트 완료: %d개 태그 검증됨", len(expectedTags))
}
