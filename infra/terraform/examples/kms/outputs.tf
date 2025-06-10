output "key_id" {
  description = "KMS 키 ID"
  value       = module.kms.key_id
}

output "key_arn" {
  description = "KMS 키 ARN"
  value       = module.kms.key_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = module.kms.cloudwatch_log_group_name
}

output "cloudwatch_alarm_name" {
  description = "CloudWatch 경보 이름"
  value       = module.kms.cloudwatch_alarm_name
}

output "cloudtrail_name" {
  description = "CloudTrail 트레일 이름"
  value       = module.kms.cloudtrail_name
}

output "s3_bucket_name" {
  description = "CloudTrail S3 버킷 이름"
  value       = module.kms.s3_bucket_name
} 