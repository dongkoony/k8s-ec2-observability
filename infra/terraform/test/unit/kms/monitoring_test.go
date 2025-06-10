package kms

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// TestCloudWatchConfiguration CloudWatch 설정 테스트
func TestCloudWatchConfiguration(t *testing.T) {
	t.Parallel()

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// KMS 키 및 CloudWatch 설정 생성
	terraform.InitAndApply(t, terraformOptions)

	// CloudWatch 로그 그룹 검증
	logGroupName := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
	exists, err := awsClient.ValidateCloudWatchLogGroup(logGroupName)
	assert.NoError(t, err)
	assert.True(t, exists, "CloudWatch 로그 그룹이 존재해야 합니다")

	// CloudWatch 경보 검증
	alarmName := terraform.Output(t, terraformOptions, "cloudwatch_alarm_name")
	alarm, err := awsClient.ValidateCloudWatchAlarm(alarmName)
	assert.NoError(t, err)
	assert.NotNil(t, alarm)
	assert.Equal(t, "ALARM", *alarm.StateValue, "CloudWatch 경보가 활성화되어 있어야 합니다")
}

// TestCloudTrailConfiguration CloudTrail 설정 테스트
func TestCloudTrailConfiguration(t *testing.T) {
	t.Parallel()

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// KMS 키 및 CloudTrail 설정 생성
	terraform.InitAndApply(t, terraformOptions)

	// CloudTrail 트레일 검증
	trailName := terraform.Output(t, terraformOptions, "cloudtrail_name")
	trail, err := awsClient.ValidateCloudTrail(trailName)
	assert.NoError(t, err)
	assert.NotNil(t, trail)
	assert.True(t, *trail.IsMultiRegionTrail, "CloudTrail이 다중 리전으로 설정되어 있어야 합니다")

	// CloudTrail 로깅 상태 검증
	isLogging, err := awsClient.ValidateCloudTrailLogging(trailName)
	assert.NoError(t, err)
	assert.True(t, isLogging, "CloudTrail 로깅이 활성화되어 있어야 합니다")

	// S3 버킷 검증
	bucketName := terraform.Output(t, terraformOptions, "cloudtrail_s3_bucket")
	exists, err := awsClient.ValidateS3Bucket(bucketName)
	assert.NoError(t, err)
	assert.True(t, exists, "CloudTrail S3 버킷이 존재해야 합니다")
}
