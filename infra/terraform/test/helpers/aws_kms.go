package helpers

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/kms"
)

// ValidateKMSKey KMS 키 검증
func (c *AWSTestClient) ValidateKMSKey(keyID string) (*kms.DescribeKeyOutput, error) {
	input := &kms.DescribeKeyInput{
		KeyId: &keyID,
	}
	return c.KMS.DescribeKey(input)
}

// GetKeyRotationStatus KMS 키 로테이션 상태 확인
func (c *AWSTestClient) GetKeyRotationStatus(keyID string) (*kms.GetKeyRotationStatusOutput, error) {
	input := &kms.GetKeyRotationStatusInput{
		KeyId: &keyID,
	}
	return c.KMS.GetKeyRotationStatus(input)
}

// GetKMSKeyTags KMS 키의 태그 목록 조회
func (c *AWSTestClient) GetKMSKeyTags(keyID string) (map[string]string, error) {
	input := &kms.ListResourceTagsInput{
		KeyId: aws.String(keyID),
	}

	result, err := c.KMS.ListResourceTags(input)
	if err != nil {
		return nil, err
	}

	tags := make(map[string]string)
	for _, tag := range result.Tags {
		tags[*tag.TagKey] = *tag.TagValue
	}

	return tags, nil
}
