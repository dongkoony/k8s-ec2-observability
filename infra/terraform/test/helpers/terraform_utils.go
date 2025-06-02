package helpers

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TerraformConfig Terraform 설정을 위한 구조체
type TerraformConfig struct {
	ModulePath string
	Vars       map[string]interface{}
	EnvVars    map[string]string
}

// SetupTerraform Terraform 테스트 설정
func SetupTerraform(t *testing.T, config TerraformConfig) *terraform.Options {
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: config.ModulePath,
		Vars:         config.Vars,
		EnvVars:      config.EnvVars,
	})
}

// DefaultKMSVars 기본 KMS 변수 설정
func DefaultKMSVars(projectName, environment string) map[string]interface{} {
	return map[string]interface{}{
		"project_name": projectName,
		"environment":  environment,
		"tags": map[string]string{
			"Terraform": "true",
			"Project":   projectName,
		},
		"deletion_window_in_days": 7,
		"enable_key_rotation":     true,
	}
}
