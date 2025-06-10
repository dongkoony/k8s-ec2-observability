package helpers

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/s3"
)

// ValidateS3Bucket S3 버킷 존재 여부 검증
func (c *AWSTestClient) ValidateS3Bucket(bucketName string) (bool, error) {
	_, err := c.S3.HeadBucket(&s3.HeadBucketInput{
		Bucket: aws.String(bucketName),
	})

	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			switch aerr.Code() {
			case "NotFound", "NoSuchBucket":
				return false, nil
			}
		}
		return false, err
	}

	return true, nil
}