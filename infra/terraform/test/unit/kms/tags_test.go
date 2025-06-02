package kms

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

func TestKMSKeyTags(t *testing.T) {
	t.Parallel()

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	customTags := map[string]string{
		"Environment": environment,
		"Project":     projectName,
		"Team":        "DevOps",
		"Terraform":   "true",
	}

	// 테스트 설정
	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/kms",
		Vars: map[string]interface{}{
			"project_name":            projectName,
			"environment":             environment,
			"enable_key_rotation":     true,
			"deletion_window_in_days": 7,
			"alias_name":              fmt.Sprintf("alias/%s-%s-key", projectName, uniqueID),
			"tags":                    customTags,
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

	// 태그 목록 가져오기
	tags, err := awsClient.GetKMSKeyTags(keyID)
	assert.NoError(t, err)

	// 필수 태그 검증
	for k, v := range customTags {
		assert.Equal(t, v, tags[k], "Tag %s should have value %s", k, v)
	}

	// Name 태그 검증
	assert.Equal(t, projectName+"-kms-key", tags["Name"], "Name tag should be correctly formatted")
}
