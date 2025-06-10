package helpers

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudtrail"
	"github.com/aws/aws-sdk-go/service/cloudwatch"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/s3"
)

// AWSTestClient AWS 테스트에 사용되는 클라이언트 구조체
type AWSTestClient struct {
	Region         string
	KMS            *kms.KMS
	EC2            *ec2.EC2
	CloudWatch     *cloudwatch.CloudWatch
	CloudWatchLogs *cloudwatchlogs.CloudWatchLogs
	CloudTrail     *cloudtrail.CloudTrail
	S3             *s3.S3
}

// NewAWSTestClient 새로운 AWS 테스트 클라이언트 생성
func NewAWSTestClient(t *testing.T, region string) *AWSTestClient {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(region),
	}))

	return &AWSTestClient{
		Region:         region,
		KMS:            kms.New(sess),
		EC2:            ec2.New(sess),
		CloudWatch:     cloudwatch.New(sess),
		CloudWatchLogs: cloudwatchlogs.New(sess),
		CloudTrail:     cloudtrail.New(sess),
		S3:             s3.New(sess),
	}
}
