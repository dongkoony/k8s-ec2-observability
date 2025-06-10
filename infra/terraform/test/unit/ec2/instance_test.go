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

	t.Logf("🖥️ EC2 인스턴스 생성 테스트 시작...")

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	// 테스트 설정
	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-master",
		Vars: map[string]interface{}{
			"project_name":  projectName,
			"ami_id":        "ami-08943a151bd468f4e", // Ubuntu 22.04 LTS
			"instance_type": "t3.micro",
			"subnet_id":     "subnet-0da71e4d6ec33bb2f",
			"vpc_id":        "vpc-058a9f815567295d2",
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"Name":        fmt.Sprintf("%s-%s-master", projectName, uniqueID),
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	defer terraform.Destroy(t, terraformOptions)

	// 리소스 생성
	t.Logf("🚀 EC2 Master 노드 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// 인스턴스 ID 가져오기
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	t.Logf("🔍 생성된 인스턴스 ID: %s", instanceID)

	// 인스턴스 검증
	t.Logf("🔍 EC2 인스턴스 상태 검증 중...")
	instance, err := awsClient.ValidateEC2Instance(instanceID)
	assert.NoError(t, err)
	assert.NotNil(t, instance)
	assert.Equal(t, "t3.micro", *instance.InstanceType)
	assert.Equal(t, "running", *instance.State.Name)

	// 태그 검증
	t.Logf("🏷️ EC2 인스턴스 태그 검증 중...")
	tags, err := awsClient.GetEC2InstanceTags(instanceID)
	assert.NoError(t, err)
	assert.Equal(t, projectName, tags["Project"])
	assert.Equal(t, environment, tags["Environment"])
	assert.Equal(t, "true", tags["Terraform"])
	assert.Equal(t, fmt.Sprintf("%s-master", projectName), tags["Name"])

	// 보안 그룹 검증
	t.Logf("🛡️ 보안 그룹 검증 중...")
	sgID := terraform.Output(t, terraformOptions, "security_group_id")
	sg, err := awsClient.ValidateSecurityGroup(sgID)
	assert.NoError(t, err)
	assert.NotNil(t, sg)

	t.Logf("✅ EC2 인스턴스 생성 테스트 완료: %s (%s)", instanceID, *instance.InstanceType)
}
