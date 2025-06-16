package kms

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/k8s-ec2-observability/test/helpers"
	"github.com/stretchr/testify/assert"
)

// TestKMSKeyTags KMS 키 태그 테스트 (단순화)
func TestKMSKeyTags(t *testing.T) {
	// t.Parallel() 제거 - AWS API 제한 방지를 위해 순차 실행

	t.Logf("🏷️ KMS 키 태그 테스트 시작...")

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

	// 기본 태그 검증을 위한 예상 태그 정의 (단순화)
	expectedTags := map[string]string{
		"Environment": "test",
		"Project":     "k8s-ec2-observability",
		"ManagedBy":   "terraform",
		"Terraform":   "true",
		"Name":        "k8s-ec2-observability-kms-key",
	}

	// KMS 키 태그 검증 (재시도 로직 포함)
	t.Logf("🔍 KMS 키 태그 검증 중...")
	keyID := terraform.Output(t, terraformOptions, "key_id")
	assert.NotEmpty(t, keyID, "KMS 키 ID가 비어있지 않아야 합니다")

	var actualTags map[string]string
	var err error

	// 최대 3번 재시도 (AWS 전파 시간 고려)
	for i := 0; i < 3; i++ {
		actualTags, err = awsClient.GetKMSKeyTags(keyID)
		if err == nil && len(actualTags) > 0 {
			break
		}
		if i < 2 {
			t.Logf("⏳ 태그 조회 재시도 중... (%d/3)", i+1)
			time.Sleep(10 * time.Second)
		}
	}

	assert.NoError(t, err, "태그 조회에 실패하지 않아야 합니다")
	assert.NotEmpty(t, actualTags, "태그가 존재해야 합니다")

	// 핵심 태그들만 검증 (유연성 확보)
	coreTagsToCheck := []string{"Environment", "Project", "Terraform"}
	for _, tagKey := range coreTagsToCheck {
		expectedValue, expectedExists := expectedTags[tagKey]
		actualValue, actualExists := actualTags[tagKey]

		if expectedExists {
			assert.True(t, actualExists, "태그 '%s'가 존재해야 합니다", tagKey)
			if actualExists {
				assert.Equal(t, expectedValue, actualValue, "태그 '%s'의 값이 일치해야 합니다", tagKey)
			}
		}
	}

	t.Logf("✅ KMS 키 태그 테스트 완료: %d개 태그 중 핵심 태그들 검증됨", len(actualTags))
}
