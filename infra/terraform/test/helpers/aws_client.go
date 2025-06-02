package helpers

import (
	"testing"

	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/kms"
	awsSDK "github.com/gruntwork-io/terratest/modules/aws"
)

// AWSTestClient AWS 테스트에 사용되는 클라이언트 구조체
type AWSTestClient struct {
	Region    string
	KMSClient *kms.KMS
	EC2Client *ec2.EC2
}

// NewAWSTestClient 새로운 AWS 테스트 클라이언트 생성
func NewAWSTestClient(t *testing.T, region string) *AWSTestClient {
	return &AWSTestClient{
		Region:    region,
		KMSClient: awsSDK.NewKmsClient(t, region),
		EC2Client: awsSDK.NewEc2Client(t, region),
	}
}

// ValidateEC2Instance EC2 인스턴스 검증
func (c *AWSTestClient) ValidateEC2Instance(instanceID string) (*ec2.Instance, error) {
	input := &ec2.DescribeInstancesInput{
		InstanceIds: []*string{&instanceID},
	}

	result, err := c.EC2Client.DescribeInstances(input)
	if err != nil {
		return nil, err
	}

	if len(result.Reservations) > 0 && len(result.Reservations[0].Instances) > 0 {
		return result.Reservations[0].Instances[0], nil
	}

	return nil, nil
}

// GetEC2InstanceTags EC2 인스턴스의 태그 목록 조회
func (c *AWSTestClient) GetEC2InstanceTags(instanceID string) (map[string]string, error) {
	instance, err := c.ValidateEC2Instance(instanceID)
	if err != nil {
		return nil, err
	}

	tags := make(map[string]string)
	for _, tag := range instance.Tags {
		tags[*tag.Key] = *tag.Value
	}

	return tags, nil
}

// ValidateSecurityGroup 보안 그룹 검증
func (c *AWSTestClient) ValidateSecurityGroup(groupID string) (*ec2.SecurityGroup, error) {
	input := &ec2.DescribeSecurityGroupsInput{
		GroupIds: []*string{&groupID},
	}

	result, err := c.EC2Client.DescribeSecurityGroups(input)
	if err != nil {
		return nil, err
	}

	if len(result.SecurityGroups) > 0 {
		return result.SecurityGroups[0], nil
	}

	return nil, nil
}

// ValidateKMSKey KMS 키 검증
func (c *AWSTestClient) ValidateKMSKey(keyID string) (*kms.DescribeKeyOutput, error) {
	input := &kms.DescribeKeyInput{
		KeyId: &keyID,
	}
	return c.KMSClient.DescribeKey(input)
}

// GetKeyRotationStatus KMS 키 로테이션 상태 확인
func (c *AWSTestClient) GetKeyRotationStatus(keyID string) (*kms.GetKeyRotationStatusOutput, error) {
	input := &kms.GetKeyRotationStatusInput{
		KeyId: &keyID,
	}
	return c.KMSClient.GetKeyRotationStatus(input)
}

// GetKMSKeyTags KMS 키의 태그 목록 조회
func (c *AWSTestClient) GetKMSKeyTags(keyID string) (map[string]string, error) {
	input := &kms.ListResourceTagsInput{
		KeyId: &keyID,
	}

	result, err := c.KMSClient.ListResourceTags(input)
	if err != nil {
		return nil, err
	}

	tags := make(map[string]string)
	for _, tag := range result.Tags {
		tags[*tag.TagKey] = *tag.TagValue
	}

	return tags, nil
}
