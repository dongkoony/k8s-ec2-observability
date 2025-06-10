package helpers

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// ValidateKMSKeyOutput KMS 키 출력값 검증
func ValidateKMSKeyOutput(t *testing.T, awsClient *AWSTestClient, terraformOptions *terraform.Options) (string, string) {
	keyID := terraform.Output(t, terraformOptions, "key_id")
	keyArn := terraform.Output(t, terraformOptions, "key_arn")
	assert.NotEmpty(t, keyID, "KMS 키 ID가 비어있지 않아야 합니다")
	assert.NotEmpty(t, keyArn, "KMS 키 ARN이 비어있지 않아야 합니다")
	return keyID, keyArn
}
