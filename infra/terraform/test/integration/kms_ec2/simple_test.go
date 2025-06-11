package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// 간단한 KMS 테스트로 실패 원인 파악
func TestSimpleKMSCreation(t *testing.T) {
	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	t.Logf("🔍 간단한 KMS 테스트 시작: %s", uniqueID)

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/kms",
		Vars: map[string]interface{}{
			"project_name":         projectName,
			"environment":          environment,
			"unique_id":            uniqueID,
			"enable_monitoring":    false,
			"enable_cloudtrail":    false,
			"enable_backup":        false,
			"enable_auto_recovery": false,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)

	// 정리 설정
	defer terraform.Destroy(t, terraformOptions)

	// Terraform 실행
	terraform.InitAndApply(t, terraformOptions)

	// 기본 출력만 확인
	kmsKeyId := terraform.Output(t, terraformOptions, "key_id")
	t.Logf("✅ KMS Key ID: %s", kmsKeyId)

	// 간단한 assertion만
	assert.NotEmpty(t, kmsKeyId, "KMS Key ID should not be empty")

	t.Logf("✅ 간단한 KMS 테스트 완료")
}
