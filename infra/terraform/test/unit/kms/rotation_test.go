package kms

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// KMS 키 로테이션 테스트
func TestKMSKeyRotation(t *testing.T) {
	t.Parallel()

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// KMS 키 생성
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 로테이션 검증
	keyID, _ := helpers.ValidateKMSKeyOutput(t, awsClient, terraformOptions)
	rotationStatus, err := awsClient.GetKeyRotationStatus(keyID)
	assert.NoError(t, err)
	assert.True(t, *rotationStatus.KeyRotationEnabled, "KMS 키 로테이션이 활성화되어야 합니다")
}
