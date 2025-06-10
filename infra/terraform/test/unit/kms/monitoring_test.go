package kms

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// CloudWatch 설정 테스트
func TestCloudWatchConfiguration(t *testing.T) {
	// 병렬 실행 비활성화로 리소스 충돌 방지
	// t.Parallel()

	t.Logf("📊 CloudWatch 설정 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// KMS 키 생성
	t.Logf("🔐 KMS 키 및 CloudWatch 리소스 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// CloudWatch 로그 그룹 검증
	t.Logf("📋 CloudWatch 로그 그룹 검증 중...")
	logGroupName := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
	exists, err := awsClient.ValidateCloudWatchLogGroup(logGroupName)
	assert.NoError(t, err)
	assert.True(t, exists, "CloudWatch 로그 그룹이 존재해야 합니다")

	// CloudWatch 경보 검증
	t.Logf("🚨 CloudWatch 경보 검증 중...")
	alarmName := terraform.Output(t, terraformOptions, "cloudwatch_alarm_name")
	alarm, err := awsClient.ValidateCloudWatchAlarm(alarmName)
	assert.NoError(t, err)
	assert.NotNil(t, alarm, "CloudWatch 경보가 존재해야 합니다")

	t.Logf("✅ CloudWatch 설정 테스트 완료: 로그 그룹 및 경보 활성화됨")
}

// CloudTrail 설정 테스트
func TestCloudTrailConfiguration(t *testing.T) {
	// 병렬 실행 비활성화로 리소스 충돌 방지
	// t.Parallel()

	t.Logf("🛤️ CloudTrail 설정 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// KMS 키 생성
	t.Logf("🔐 KMS 키 및 CloudTrail 리소스 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// CloudTrail 검증
	t.Logf("🔍 CloudTrail 설정 검증 중...")
	trailName := terraform.Output(t, terraformOptions, "cloudtrail_name")
	trail, err := awsClient.ValidateCloudTrail(trailName)
	assert.NoError(t, err)
	assert.NotNil(t, trail, "CloudTrail이 존재해야 합니다")

	// S3 버킷 검증
	t.Logf("🪣 CloudTrail S3 버킷 검증 중...")
	bucketName := terraform.Output(t, terraformOptions, "s3_bucket_name")
	bucketExists, err := awsClient.ValidateS3Bucket(bucketName)
	assert.NoError(t, err)
	assert.True(t, bucketExists, "CloudTrail S3 버킷이 존재해야 합니다")

	t.Logf("✅ CloudTrail 설정 테스트 완료: 감사 로깅 활성화됨")
}
