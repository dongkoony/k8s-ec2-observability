package integration

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// 테스트 간 데이터 공유를 위한 전역 변수
var (
	testKMSKeyID         string
	testMasterInstanceID string
	testMasterPrivateIP  string
	testMasterSGID       string
	// 정리용 terraform options들
	kmsOptions    *terraform.Options
	masterOptions *terraform.Options
	workerOptions *terraform.Options
)

func TestKubernetesClusterIntegration(t *testing.T) {
	// 통합 테스트는 순차 실행 (리소스 의존성 때문에)
	// t.Parallel()

	awsRegion := "ap-northeast-2"
	projectName := "k8s-ec2-observability"
	environment := "test"
	uniqueID := random.UniqueId()

	awsClient := helpers.NewAWSTestClient(t, awsRegion)

	t.Logf("🚀 통합 테스트 시작: %s-%s", projectName, uniqueID)

	// 1단계: KMS 키 생성 및 observability 설정
	t.Run("KMS_Setup", func(t *testing.T) {
		testKMSSetup(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 2단계: Master 노드 생성 (KMS 암호화 EBS)
	t.Run("Master_Node", func(t *testing.T) {
		testMasterNode(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 3단계: Worker 노드들 생성 (Master 의존성 포함)
	t.Run("Worker_Nodes", func(t *testing.T) {
		testWorkerNodes(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 4단계: 전체 시스템 검증
	t.Run("System_Validation", func(t *testing.T) {
		testSystemValidation(t, awsClient, awsRegion, projectName, environment, uniqueID)
	})

	// 모든 리소스 정리 (역순으로)
	t.Cleanup(func() {
		t.Logf("🧹 리소스 정리 시작...")
		if workerOptions != nil {
			t.Logf("Worker 노드들 정리 중...")
			terraform.Destroy(t, workerOptions)
		}
		if masterOptions != nil {
			t.Logf("Master 노드 정리 중...")
			terraform.Destroy(t, masterOptions)
		}
		if kmsOptions != nil {
			t.Logf("KMS 리소스 정리 중...")
			terraform.Destroy(t, kmsOptions)
		}
		t.Logf("✅ 모든 리소스 정리 완료!")
	})

	t.Logf("✅ 통합 테스트 완료: %s-%s", projectName, uniqueID)
}

func testKMSSetup(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("🔐 KMS 설정 테스트 시작...")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/kms",
		Vars: map[string]interface{}{
			"project_name":         projectName,
			"environment":          environment,
			"unique_id":            uniqueID,
			"enable_monitoring":    false, // 권한 문제로 비활성화
			"enable_cloudtrail":    false, // 권한 문제로 비활성화
			"enable_backup":        false, // 권한 문제로 비활성화
			"enable_auto_recovery": false, // Lambda/EventBridge 권한 문제로 비활성화
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	kmsOptions = terraformOptions // 전역 변수에 저장

	// KMS 리소스 생성
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 검증
	kmsKeyId := terraform.Output(t, terraformOptions, "key_id")
	kmsKey, err := awsClient.ValidateKMSKey(kmsKeyId)
	assert.NoError(t, err)
	assert.NotNil(t, kmsKey)
	assert.Equal(t, "Enabled", *kmsKey.KeyMetadata.KeyState)

	// 고급 기능들이 비활성화되어 있으므로 기본 KMS 키 검증만 수행
	t.Logf("⚠️  고급 기능들(CloudTrail, 모니터링, 백업)이 권한 문제로 비활성화됨")

	// KMS 키 ID를 전역 변수에 저장
	testKMSKeyID = kmsKeyId

	// KMS 키 안정화를 위한 대기 시간 추가 (5분)
	t.Logf("⏱️  KMS 키 안정화 대기 중... (5분 - EC2 사용을 위한 충분한 전파 시간)")
	time.Sleep(5 * time.Minute)

	// KMS 키가 EC2에서 사용 가능한 상태인지 추가 검증
	t.Logf("🔍 KMS 키 EC2 사용 가능성 최종 검증 중...")
	for i := 0; i < 6; i++ { // 최대 60초 추가 검증
		kmsKey, err := awsClient.ValidateKMSKey(kmsKeyId)
		if err == nil && kmsKey != nil && *kmsKey.KeyMetadata.KeyState == "Enabled" {
			t.Logf("✅ KMS 키 EC2 사용 준비 완료 (시도 %d/6)", i+1)

			// 추가 검증: KMS 키가 실제로 EC2 암호화에 사용 가능한지 확인
			t.Logf("🔐 KMS 키 암호화 기능 검증 중...")
			if *kmsKey.KeyMetadata.KeyUsage == "ENCRYPT_DECRYPT" &&
				*kmsKey.KeyMetadata.KeyState == "Enabled" {
				t.Logf("✅ KMS 키 암호화 기능 검증 완료")
				break
			}
		}
		if i < 5 {
			t.Logf("⏳ KMS 키 상태 재확인 중... (10초 후 재시도)")
			time.Sleep(10 * time.Second)
		}
	}

	t.Logf("✅ KMS 설정 완료: %s", kmsKeyId)
}

func testMasterNode(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("🎯 Master 노드 테스트 시작...")

	assert.NotEmpty(t, testKMSKeyID, "KMS Key ID가 설정되지 않았습니다")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-master",
		Vars: map[string]interface{}{
			"project_name":  projectName,
			"ami_id":        "ami-08943a151bd468f4e", // Ubuntu 22.04 LTS
			"instance_type": "t3.small",              // Master는 좀 더 큰 인스턴스
			"subnet_id":     "subnet-0da71e4d6ec33bb2f",
			"vpc_id":        "vpc-058a9f815567295d2",
			"kms_key_id":    testKMSKeyID, // KMS 암호화 적용
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"TestType":    "Integration",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	masterOptions = terraformOptions // 전역 변수에 저장

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

	testMasterInstanceID = instanceID
	testMasterPrivateIP = privateIP
	testMasterSGID = sgID

	t.Logf("✅ Master 노드 완료: %s (IP: %s)", instanceID, privateIP)
}

func testWorkerNodes(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("👥 Worker 노드들 테스트 시작...")

	assert.NotEmpty(t, testKMSKeyID, "KMS Key ID가 필요합니다")
	assert.NotEmpty(t, testMasterPrivateIP, "Master Private IP가 필요합니다")
	assert.NotEmpty(t, testMasterSGID, "Master Security Group ID가 필요합니다")

	tfConfig := helpers.TerraformConfig{
		ModulePath: "../../../modules/ec2-worker",
		Vars: map[string]interface{}{
			"project_name":             projectName,
			"worker_count":             2,                       // 2개 워커 노드
			"ami_id":                   "ami-08943a151bd468f4e", // Ubuntu 22.04 LTS
			"instance_type":            "t3.micro",
			"subnet_id":                "subnet-0da71e4d6ec33bb2f",
			"vpc_id":                   "vpc-058a9f815567295d2",
			"master_private_ip":        testMasterPrivateIP,
			"master_security_group_id": testMasterSGID,
			"kms_key_id":               testKMSKeyID, // KMS 암호화 적용
			"tags": map[string]string{
				"Terraform":   "true",
				"Project":     projectName,
				"Environment": environment,
				"TestType":    "Integration",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	terraformOptions := helpers.SetupTerraform(t, tfConfig)
	workerOptions = terraformOptions // 전역 변수에 저장

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

		t.Logf("✅ Worker-%d 노드 완료: %s", i+1, workerID)
	}

	t.Logf("✅ 모든 Worker 노드들 완료: %v", workerIDs)
}

func testSystemValidation(t *testing.T, awsClient *helpers.AWSTestClient, awsRegion, projectName, environment, uniqueID string) {
	t.Logf("🔍 전체 시스템 검증 시작...")

	assert.NotEmpty(t, testKMSKeyID, "KMS Key ID가 필요합니다")
	assert.NotEmpty(t, testMasterInstanceID, "Master Instance ID가 필요합니다")

	// 1. KMS 키 사용 검증
	t.Run("KMS_Usage", func(t *testing.T) {
		if testKMSKeyID == "" {
			t.Skip("KMS Key ID가 설정되지 않았습니다. KMS_Setup 단계가 실패했을 수 있습니다.")
			return
		}
		// KMS 키가 활성 상태이고 사용 가능한지 확인
		kmsKey, err := awsClient.ValidateKMSKey(testKMSKeyID)
		assert.NoError(t, err)
		assert.NotNil(t, kmsKey)
		assert.Equal(t, "Enabled", *kmsKey.KeyMetadata.KeyState)
	})

	// 2. 네트워크 연결성 검증 (간접적)
	t.Run("Network_Connectivity", func(t *testing.T) {
		if testMasterInstanceID == "" {
			t.Skip("Master Instance ID가 설정되지 않았습니다. Master_Node 단계가 실패했을 수 있습니다.")
			return
		}
		// Master 노드가 실행 중이고 네트워크 인터페이스가 활성화되어 있는지 확인
		instance, err := awsClient.ValidateEC2Instance(testMasterInstanceID)
		assert.NoError(t, err)
		assert.NotNil(t, instance)
		assert.NotEmpty(t, instance.NetworkInterfaces)
		assert.NotNil(t, instance.PrivateIpAddress)
		assert.Equal(t, testMasterPrivateIP, *instance.PrivateIpAddress)
	})

	// 3. 태그 일관성 검증
	t.Run("Tag_Consistency", func(t *testing.T) {
		if testMasterInstanceID == "" {
			t.Skip("Master Instance ID가 설정되지 않았습니다. Master_Node 단계가 실패했을 수 있습니다.")
			return
		}
		tags, err := awsClient.GetEC2InstanceTags(testMasterInstanceID)
		assert.NoError(t, err)
		assert.Equal(t, projectName, tags["Project"])
		assert.Equal(t, environment, tags["Environment"])
		assert.Equal(t, "Integration", tags["TestType"])
		assert.Equal(t, "true", tags["Terraform"])
	})

	t.Logf("✅ 전체 시스템 검증 완료!")
}
