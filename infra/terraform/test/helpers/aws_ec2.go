package helpers

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
)

// ValidateEC2Instance EC2 인스턴스 검증
func (c *AWSTestClient) ValidateEC2Instance(instanceID string) (*ec2.Instance, error) {
	input := &ec2.DescribeInstancesInput{
		InstanceIds: []*string{&instanceID},
	}

	result, err := c.EC2.DescribeInstances(input)
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
		GroupIds: []*string{aws.String(groupID)},
	}

	result, err := c.EC2.DescribeSecurityGroups(input)
	if err != nil {
		return nil, err
	}

	if len(result.SecurityGroups) > 0 {
		return result.SecurityGroups[0], nil
	}

	return nil, nil
}
