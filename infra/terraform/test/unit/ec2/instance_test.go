package ec2

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

func TestEC2InstanceCreation(t *testing.T) {
	t.Parallel()

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	// 테스트 설정
	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2",
		Vars: map[string]interface{}{
			"project_name":  projectName,
			"environment":   environment,
			"instance_name": fmt.Sprintf("%s-%s-instance", projectName, uniqueID),
			"instance_type": "t3.micro",
			"ami_id":        "ami-0c9c942bd7bf113a2",    // Amazon Linux 2
			"subnet_id":     "subnet-0123456789abcdef0", // TODO: VPC 모듈에서 생성된 서브넷 ID 사용
			"key_name":      fmt.Sprintf("%s-%s-key", projectName, uniqueID),
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

	// 인스턴스 ID 가져오기
	instanceID := terraform.Output(t, terraformOptions, "instance_id")

	// 인스턴스 검증
	instance, err := awsClient.ValidateEC2Instance(instanceID)
	assert.NoError(t, err)
	assert.NotNil(t, instance)
	assert.Equal(t, "t3.micro", *instance.InstanceType)
	assert.Equal(t, "running", *instance.State.Name)

	// 태그 검증
	tags, err := awsClient.GetEC2InstanceTags(instanceID)
	assert.NoError(t, err)
	assert.Equal(t, projectName, tags["Project"])
	assert.Equal(t, environment, tags["Environment"])
	assert.Equal(t, "true", tags["Terraform"])
	assert.Equal(t, fmt.Sprintf("%s-%s-instance", projectName, uniqueID), tags["Name"])

	// 보안 그룹 검증
	sgID := terraform.Output(t, terraformOptions, "security_group_id")
	sg, err := awsClient.ValidateSecurityGroup(sgID)
	assert.NoError(t, err)
	assert.NotNil(t, sg)

	// TODO: IAM 역할 검증 추가
	// TODO: KMS 키 연동 검증 추가
}
