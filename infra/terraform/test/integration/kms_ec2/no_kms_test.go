package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// KMS 없이 EC2만 테스트하는 백업 테스트
func TestEC2WithoutKMS(t *testing.T) {
	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	t.Logf("🚀 KMS 없이 EC2 테스트 시작: %s", uniqueID)

	// 1. Master 노드 생성 (KMS 없이)
	t.Run("Master_Without_KMS", func(t *testing.T) {
		tfConfig := helpers.TerraformConfig{
			ModulePath: "../../../modules/ec2-master",
			Vars: map[string]interface{}{
				"project_name":  projectName,
				"ami_id":        "ami-08943a151bd468f4e",
				"instance_type": "t3.small",
				"subnet_id":     "subnet-0da71e4d6ec33bb2f",
				"vpc_id":        "vpc-058a9f815567295d2",
				"kms_key_id":    "", // KMS 없이 테스트
				"tags": map[string]string{
					"Terraform":   "true",
					"Project":     projectName,
					"Environment": environment,
					"TestType":    "NoKMS",
				},
			},
			EnvVars: map[string]string{
				"AWS_DEFAULT_REGION": awsRegion,
			},
		}

		terraformOptions := helpers.SetupTerraform(t, tfConfig)
		defer terraform.Destroy(t, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)

		instanceID := terraform.Output(t, terraformOptions, "instance_id")
		privateIP := terraform.Output(t, terraformOptions, "private_ip")
		sgID := terraform.Output(t, terraformOptions, "security_group_id")

		t.Logf("✅ Master (KMS 없이): %s, IP: %s, SG: %s", instanceID, privateIP, sgID)

		// 2. Worker 노드 생성 (KMS 없이)
		t.Run("Worker_Without_KMS", func(t *testing.T) {
			workerTfConfig := helpers.TerraformConfig{
				ModulePath: "../../../modules/ec2-worker",
				Vars: map[string]interface{}{
					"project_name":             projectName,
					"worker_count":             1, // 1개만 테스트
					"ami_id":                   "ami-08943a151bd468f4e",
					"instance_type":            "t3.micro",
					"subnet_id":                "subnet-0da71e4d6ec33bb2f",
					"vpc_id":                   "vpc-058a9f815567295d2",
					"master_private_ip":        privateIP,
					"master_security_group_id": sgID,
					"kms_key_id":               "", // KMS 없이 테스트
					"tags": map[string]string{
						"Terraform":   "true",
						"Project":     projectName,
						"Environment": environment,
						"TestType":    "NoKMS",
					},
				},
				EnvVars: map[string]string{
					"AWS_DEFAULT_REGION": awsRegion,
				},
			}

			workerOptions := helpers.SetupTerraform(t, workerTfConfig)
			defer terraform.Destroy(t, workerOptions)

			terraform.InitAndApply(t, workerOptions)

			workerIDs := terraform.OutputList(t, workerOptions, "instance_ids")
			assert.Equal(t, 1, len(workerIDs))

			t.Logf("✅ Worker (KMS 없이): %v", workerIDs)
		})
	})

	t.Logf("✅ KMS 없이 EC2 테스트 완료!")
}
