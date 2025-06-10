package helpers

import (
	"fmt"
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
	uniqueID := random.UniqueId()
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

// SetupKMSTest KMS 테스트 설정 초기화
func SetupKMSTest(t *testing.T, config *KMSTestConfig) *terraform.Options {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: config.TestFolder,
		Vars: map[string]interface{}{
			"region":               config.Region,
			"project_name":         config.ProjectName,
			"environment":          config.Environment,
			"unique_id":            config.UniqueID,
			"test_name":            fmt.Sprintf("kms-test-%s", config.UniqueID),
			"enable_multi_region":  false,
			"replica_region":       "us-west-2",
			"enable_backup":        false,
			"enable_auto_recovery": false,
			"enable_monitoring":    false,
			"enable_cloudtrail":    false,
			"tags":                 config.Tags,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": config.Region,
		},
		NoColor:            true,
		Reconfigure:        true,
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	})

	// 테스트 종료 시 리소스 정리
	t.Cleanup(func() {
		terraform.Destroy(t, terraformOptions)
	})

	return terraformOptions
}
