package helpers

import (
	"fmt"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/cloudtrail"
	"github.com/aws/aws-sdk-go/service/cloudwatch"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
)

// ValidateCloudWatchLogGroup CloudWatch 로그 그룹 존재 여부 검증
func (c *AWSTestClient) ValidateCloudWatchLogGroup(logGroupName string) (bool, error) {
	input := &cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(logGroupName),
	}

	result, err := c.CloudWatchLogs.DescribeLogGroups(input)
	if err != nil {
		return false, err
	}

	for _, group := range result.LogGroups {
		if *group.LogGroupName == logGroupName {
			return true, nil
		}
	}

	return false, nil
}

// ValidateCloudWatchAlarm CloudWatch 경보 검증
func (c *AWSTestClient) ValidateCloudWatchAlarm(alarmName string) (*cloudwatch.MetricAlarm, error) {
	input := &cloudwatch.DescribeAlarmsInput{
		AlarmNames: []*string{aws.String(alarmName)},
	}

	result, err := c.CloudWatch.DescribeAlarms(input)
	if err != nil {
		return nil, err
	}

	if len(result.MetricAlarms) == 0 {
		return nil, fmt.Errorf("경보를 찾을 수 없습니다: %s", alarmName)
	}

	return result.MetricAlarms[0], nil
}

// ValidateCloudTrail CloudTrail 트레일 검증
func (c *AWSTestClient) ValidateCloudTrail(trailName string) (*cloudtrail.Trail, error) {
	input := &cloudtrail.DescribeTrailsInput{
		TrailNameList: []*string{aws.String(trailName)},
	}

	result, err := c.CloudTrail.DescribeTrails(input)
	if err != nil {
		return nil, err
	}

	if len(result.TrailList) == 0 {
		return nil, fmt.Errorf("트레일을 찾을 수 없습니다: %s", trailName)
	}

	return result.TrailList[0], nil
}

// ValidateCloudTrailLogging CloudTrail 로깅 상태 검증
func (c *AWSTestClient) ValidateCloudTrailLogging(trailName string) (bool, error) {
	input := &cloudtrail.GetTrailStatusInput{
		Name: aws.String(trailName),
	}

	result, err := c.CloudTrail.GetTrailStatus(input)
	if err != nil {
		return false, err
	}

	return *result.IsLogging, nil
}
