package helpers

import (
	"fmt"
	"strings"
	"testing"

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
			"enable_monitoring":    true,
			"enable_cloudtrail":    true,
			"tags":                 config.Tags,
		},
	})

	return terraformOptions
}
