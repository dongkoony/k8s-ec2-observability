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

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()

	// 추가 태그 설정
	additionalTags := map[string]string{
		"Team":      "DevOps",
		"Terraform": "true",
	}

	// 기존 태그와 추가 태그 병합
	for k, v := range additionalTags {
		config.Tags[k] = v
	}

	// AWS 클라이언트 초기화
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// KMS 키 생성
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 유효성 검증
	keyID, _ := helpers.ValidateKMSKeyOutput(t, awsClient, terraformOptions)

	// 태그 목록 조회
	tags, err := awsClient.GetKMSKeyTags(keyID)
	assert.NoError(t, err)

	// 태그 값 검증
	for k, v := range config.Tags {
		assert.Equal(t, v, tags[k], "태그 %s의 값이 %s이어야 합니다", k, v)
	}

	// 필수 태그 검증
	requiredTags := []string{"Environment", "Project", "Name", "ManagedBy"}
	for _, tag := range requiredTags {
		assert.NotEmpty(t, tags[tag], "필수 태그 %s가 존재해야 합니다", tag)
	}
}
