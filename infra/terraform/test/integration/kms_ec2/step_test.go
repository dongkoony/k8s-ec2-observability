package integration

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// 단계별 테스트 - KMS만 먼저 검증
func TestKMSOnly(t *testing.T) {
	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	t.Logf("🔐 KMS 단독 테스트 시작: %s", uniqueID)

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
	defer terraform.Destroy(t, terraformOptions)

	// KMS 리소스 생성
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 검증
	kmsKeyId := terraform.Output(t, terraformOptions, "key_id")
	t.Logf("✅ KMS Key 생성됨: %s", kmsKeyId)

	// 안정화 대기
	t.Logf("⏱️  KMS 키 안정화 대기 (15초)...")
	time.Sleep(15 * time.Second)

	// KMS 키 상태 재확인
	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	kmsKey, err := awsClient.ValidateKMSKey(kmsKeyId)
	assert.NoError(t, err)
	assert.NotNil(t, kmsKey)
	assert.Equal(t, "Enabled", *kmsKey.KeyMetadata.KeyState)

	t.Logf("✅ KMS 키 안정화 확인됨!")
}

// 단계별 테스트 - Master 노드만 검증
func TestMasterNodeOnly(t *testing.T) {
	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"

	t.Logf("🎯 Master 노드 단독 테스트 시작...")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-master",
		Vars: map[string]interface{}{
			"project_name":  projectName,
			"ami_id":        "ami-08943a151bd468f4e",
			"instance_type": "t3.small",
			"subnet_id":     "subnet-0da71e4d6ec33bb2f",
			"vpc_id":        "vpc-058a9f815567295d2",
			"kms_key_id":    "", // KMS 키 없이 테스트
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"TestType":    "StepTest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	defer terraform.Destroy(t, terraformOptions)

	// Master 노드 생성
	terraform.InitAndApply(t, terraformOptions)

	// Master 인스턴스 검증
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	t.Logf("✅ Master 노드 생성됨: %s", instanceID)

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	instance, err := awsClient.ValidateEC2Instance(instanceID)
	assert.NoError(t, err)
	assert.NotNil(t, instance)
	assert.Equal(t, "t3.small", *instance.InstanceType)
	assert.Equal(t, "running", *instance.State.Name)

	t.Logf("✅ Master 노드 검증 완료!")
}
