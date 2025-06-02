package kms

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

func TestKMSKeyRotation(t *testing.T) {
	t.Parallel()

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	// 테스트 설정
	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/kms",
		Vars: map[string]interface{}{
			"project_name":            projectName,
			"environment":             environment,
			"enable_key_rotation":     true,
			"deletion_window_in_days": 7,
			"alias_name":              fmt.Sprintf("alias/%s-%s-key", projectName, uniqueID),
			"tags": map[string]string{
				"Terraform": "true",
				"Project":   projectName,
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	defer terraform.Destroy(t, terraformOptions)

	// 리소스 생성
	terraform.InitAndApply(t, terraformOptions)

	// 키 ID 가져오기
	keyID := terraform.Output(t, terraformOptions, "key_id")

	// 로테이션 상태 확인
	rotationStatus, err := awsClient.GetKeyRotationStatus(keyID)
	assert.NoError(t, err)
	assert.True(t, *rotationStatus.KeyRotationEnabled, "Key rotation should be enabled")
}
