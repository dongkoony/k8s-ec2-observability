package helpers

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// KMSTestConfig KMS 테스트 설정
type KMSTestConfig struct {
	Region      string
	UniqueID    string
	TestFolder  string
	Environment string
	ProjectName string
	Tags        map[string]string
}

// NewKMSTestConfig 새로운 KMS 테스트 설정 생성
func NewKMSTestConfig() *KMSTestConfig {
	uniqueID := strings.ToLower(random.UniqueId())
	projectName := "k8s-ec2-observability"

	return &KMSTestConfig{
		Region:      "ap-northeast-2",
		UniqueID:    uniqueID,
		TestFolder:  "../../../examples/kms",
		Environment: "test",
		ProjectName: projectName,
		Tags: map[string]string{
			"Environment": "test",
			"Project":     projectName,
			"ManagedBy":   "terraform",
			"Name":        fmt.Sprintf("%s-kms-key", projectName),
		},
	}
}

// SetupKMSTest KMS 테스트 설정 초기화 (GitHub Actions 최적화)
func SetupKMSTest(t *testing.T, config *KMSTestConfig) *terraform.Options {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: config.TestFolder,
		Vars: map[string]interface{}{
			"region":                  config.Region,
			"project_name":            config.ProjectName,
			"environment":             config.Environment,
			"unique_id":               config.UniqueID,
			"test_name":               fmt.Sprintf("kms-test-%s", config.UniqueID),
			"enable_multi_region":     false, // 단순화
			"replica_region":          "us-west-2",
			"enable_backup":           false, // GitHub Actions에서 권한 문제 방지
			"enable_auto_recovery":    false, // Lambda/EventBridge 권한 문제 방지
			"enable_monitoring":       false, // CloudWatch 권한 문제 방지
			"enable_cloudtrail":       false, // CloudTrail/S3 권한 문제 방지
			"deletion_window_in_days": 7,     // 최소값으로 설정
			"enable_key_rotation":     true,  // 기본 KMS 기능만 사용
			"tags":                    config.Tags,
		},
		// 재시도 설정 추가 (GitHub Actions 안정성 향상)
		RetryableTerraformErrors: map[string]string{
			".*RequestLimitExceeded.*": "AWS API 요청 제한, 재시도 중...",
			".*throttling.*":           "AWS API 스로틀링, 재시도 중...",
			".*timeout.*":              "타임아웃 발생, 재시도 중...",
			".*":                       "Terraform operation failed, retrying...",
		},
		MaxRetries:         5,                // 재시도 횟수 증가
		TimeBetweenRetries: 10 * time.Second, // 재시도 간격 증가
	})

	return terraformOptions
}
