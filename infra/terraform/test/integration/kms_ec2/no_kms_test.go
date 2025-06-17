package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// 테스트 간 데이터 공유를 위한 전역 변수 (KMS 없는 버전)
var (
	noKmsMasterInstanceID string
	noKmsMasterPrivateIP  string
	noKmsMasterSGID       string
	// 정리용 terraform options들
	noKmsMasterOptions *terraform.Options
	noKmsWorkerOptions *terraform.Options
)

// KMS 없이 EC2만 테스트하는 안정적인 통합 테스트
func TestEC2WithoutKMS(t *testing.T) {
	// 통합 테스트는 순차 실행 (리소스 의존성 때문에)
	// t.Parallel()

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	t.Logf("🚀 KMS 없이 EC2 통합 테스트 시작: %s-%s", projectName, uniqueID)

	// 1단계: Master 노드 생성 (KMS 없이)
	t.Run("Master_Without_KMS", func(t *testing.T) {
		testMasterWithoutKMS(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 2단계: Worker 노드들 생성 (Master 의존성 포함)
	t.Run("Worker_Without_KMS", func(t *testing.T) {
		testWorkerWithoutKMS(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 3단계: 전체 시스템 검증 (KMS 없이)
	t.Run("System_Validation_Without_KMS", func(t *testing.T) {
		testSystemValidationWithoutKMS(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 모든 리소스 정리 (역순으로)
	t.Cleanup(func() {
		t.Logf("🧹 리소스 정리 시작...")
		if noKmsWorkerOptions != nil {
			t.Logf("Worker 노드들 정리 중...")
			terraform.Destroy(t, noKmsWorkerOptions)
		}
		if noKmsMasterOptions != nil {
			t.Logf("Master 노드 정리 중...")
			terraform.Destroy(t, noKmsMasterOptions)
		}
		t.Logf("✅ 모든 리소스 정리 완료!")
	})

	t.Logf("✅ KMS 없이 EC2 통합 테스트 완료: %s-%s", projectName, uniqueID)
}

func testMasterWithoutKMS(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("🎯 Master 노드 테스트 시작 (KMS 없이)...")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-master",
		Vars: map[string]interface{}{
			"project_name":  projectName,
			"ami_id":        "ami-08943a151bd468f4e", // Ubuntu 22.04 LTS
			"instance_type": "t3.small",              // Master는 좀 더 큰 인스턴스
			"subnet_id":     "subnet-0da71e4d6ec33bb2f",
			"vpc_id":        "vpc-058a9f815567295d2",
			// kms_key_id는 제공하지 않음 (기본 암호화 사용)
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"TestType":    "Integration-NoKMS",
				"UniqueID":    uniqueID,
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	noKmsMasterOptions = terraformOptions // 전역 변수에 저장

	// Master 노드 생성
	terraform.InitAndApply(t, terraformOptions)

	// Master 인스턴스 검증
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	instance, err := awsClient.ValidateEC2Instance(instanceID)
	assert.NoError(t, err)
	assert.NotNil(t, instance)
	assert.Equal(t, "t3.small", *instance.InstanceType)
	assert.Equal(t, "running", *instance.State.Name)

	// Master 정보를 전역 변수에 저장
	privateIP := terraform.Output(t, terraformOptions, "private_ip")
	sgID := terraform.Output(t, terraformOptions, "security_group_id")

	noKmsMasterInstanceID = instanceID
	noKmsMasterPrivateIP = privateIP
	noKmsMasterSGID = sgID

	t.Logf("✅ Master 노드 완료 (KMS 없이): %s (IP: %s)", instanceID, privateIP)
}

func testWorkerWithoutKMS(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("👥 Worker 노드들 테스트 시작 (KMS 없이)...")

	assert.NotEmpty(t, noKmsMasterPrivateIP, "Master Private IP가 필요합니다")
	assert.NotEmpty(t, noKmsMasterSGID, "Master Security Group ID가 필요합니다")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-worker",
		Vars: map[string]interface{}{
			"project_name":             projectName,
			"worker_count":             2,                       // 2개 워커 노드
			"ami_id":                   "ami-08943a151bd468f4e", // Ubuntu 22.04 LTS
			"instance_type":            "t3.micro",
			"subnet_id":                "subnet-0da71e4d6ec33bb2f",
			"vpc_id":                   "vpc-058a9f815567295d2",
			"master_private_ip":        noKmsMasterPrivateIP,
			"master_security_group_id": noKmsMasterSGID,
			// kms_key_id는 제공하지 않음 (기본 암호화 사용)
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"TestType":    "Integration-NoKMS",
				"UniqueID":    uniqueID,
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	noKmsWorkerOptions = terraformOptions // 전역 변수에 저장

	// Worker 노드들 생성
	terraform.InitAndApply(t, terraformOptions)

	// Worker 인스턴스들 검증
	workerIDs := terraform.OutputList(t, terraformOptions, "instance_ids")
	assert.Equal(t, 2, len(workerIDs), "2개의 워커 노드가 생성되어야 합니다")

	for i, workerID := range workerIDs {
		instance, err := awsClient.ValidateEC2Instance(workerID)
		assert.NoError(t, err)
		assert.NotNil(t, instance)
		assert.Equal(t, "t3.micro", *instance.InstanceType)
		assert.Equal(t, "running", *instance.State.Name)

		t.Logf("✅ Worker-%d 노드 완료 (KMS 없이): %s", i+1, workerID)
	}

	t.Logf("✅ 모든 Worker 노드들 완료 (KMS 없이): %v", workerIDs)
}

func testSystemValidationWithoutKMS(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("🔍 전체 시스템 검증 시작 (KMS 없이)...")

	assert.NotEmpty(t, noKmsMasterInstanceID, "Master Instance ID가 필요합니다")

	// 1. 네트워크 연결성 검증
	t.Run("Network_Connectivity", func(t *testing.T) {
		// Master 노드가 실행 중이고 네트워크 인터페이스가 활성화되어 있는지 확인
		instance, err := awsClient.ValidateEC2Instance(noKmsMasterInstanceID)
		assert.NoError(t, err)
		assert.NotNil(t, instance)
		assert.NotEmpty(t, instance.NetworkInterfaces)
		assert.NotNil(t, instance.PrivateIpAddress)
		assert.Equal(t, noKmsMasterPrivateIP, *instance.PrivateIpAddress)
	})

	// 2. 태그 일관성 검증
	t.Run("Tag_Consistency", func(t *testing.T) {
		tags, err := awsClient.GetEC2InstanceTags(noKmsMasterInstanceID)
		assert.NoError(t, err)
		assert.Equal(t, projectName, tags["Project"])
		assert.Equal(t, environment, tags["Environment"])
		assert.Equal(t, "Integration-NoKMS", tags["TestType"])
		assert.Equal(t, "true", tags["Terraform"])
		assert.Equal(t, uniqueID, tags["UniqueID"])
	})

	// 3. 보안 그룹 검증
	t.Run("Security_Group_Validation", func(t *testing.T) {
		sg, err := awsClient.ValidateSecurityGroup(noKmsMasterSGID)
		assert.NoError(t, err)
		assert.NotNil(t, sg)
		assert.NotEmpty(t, sg.GroupId)
		assert.Equal(t, noKmsMasterSGID, *sg.GroupId)
	})

	// 4. EBS 볼륨 검증 (기본 암호화)
	t.Run("EBS_Volume_Validation", func(t *testing.T) {
		instance, err := awsClient.ValidateEC2Instance(noKmsMasterInstanceID)
		assert.NoError(t, err)
		assert.NotNil(t, instance)
		assert.NotEmpty(t, instance.BlockDeviceMappings)

		// 루트 볼륨이 존재하는지 확인
		for _, bdm := range instance.BlockDeviceMappings {
			if bdm.Ebs != nil {
				t.Logf("📀 EBS 볼륨 발견: %s", *bdm.Ebs.VolumeId)
				// 기본 암호화든 KMS 암호화든 상관없이 볼륨이 정상적으로 생성되었는지만 확인
				assert.NotEmpty(t, *bdm.Ebs.VolumeId)
			}
		}
	})

	t.Logf("✅ 전체 시스템 검증 완료 (KMS 없이)!")
}
