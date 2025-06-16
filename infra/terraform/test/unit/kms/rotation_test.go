package kms

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// KMS 키 로테이션 테스트 (단순화)
func TestKMSKeyRotation(t *testing.T) {
	// t.Parallel() 제거 - AWS API 제한 방지를 위해 순차 실행

	t.Logf("🔄 KMS 키 로테이션 테스트 시작...")

	// 테스트 설정 초기화
	config := helpers.NewKMSTestConfig()
	awsClient := helpers.NewAWSTestClient(t, config.Region)
	terraformOptions := helpers.SetupKMSTest(t, config)

	// 테스트 완료 후 리소스 정리
	defer func() {
		t.Logf("🧹 KMS 리소스 정리 중...")
		terraform.Destroy(t, terraformOptions)
		t.Logf("✅ KMS 리소스 정리 완료")
	}()

	// KMS 키 생성
	t.Logf("🔐 KMS 키 생성 중...")
	terraform.InitAndApply(t, terraformOptions)

	// KMS 키 로테이션 검증 (재시도 로직 포함)
	t.Logf("🔍 KMS 키 로테이션 상태 검증 중...")
	keyID := terraform.Output(t, terraformOptions, "key_id")
	assert.NotEmpty(t, keyID, "KMS 키 ID가 비어있지 않아야 합니다")

	// 로테이션 상태 확인 (재시도)
	var rotationEnabled bool
	var err error

	for i := 0; i < 3; i++ {
		rotationStatus, rotErr := awsClient.GetKeyRotationStatus(keyID)
		if rotErr == nil && rotationStatus != nil && rotationStatus.KeyRotationEnabled != nil {
			rotationEnabled = *rotationStatus.KeyRotationEnabled
			err = nil
			break
		}
		err = rotErr
		if i < 2 {
			t.Logf("⏳ 로테이션 상태 확인 재시도 중... (%d/3)", i+1)
			time.Sleep(10 * time.Second)
		}
	}

	assert.NoError(t, err, "로테이션 상태 조회에 실패하지 않아야 합니다")
	assert.True(t, rotationEnabled, "KMS 키 로테이션이 활성화되어야 합니다")

	t.Logf("✅ KMS 키 로테이션 테스트 완료: 자동 로테이션 활성화됨")
}
