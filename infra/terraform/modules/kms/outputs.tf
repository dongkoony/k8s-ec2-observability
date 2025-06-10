output "key_id" {
  description = "생성된 KMS 키의 ID"
  value       = aws_kms_key.k8s_key.key_id
}

output "key_arn" {
  description = "생성된 KMS 키의 ARN"
  value       = aws_kms_key.k8s_key.arn
}

output "alias_name" {
  description = "생성된 KMS 키의 별칭 이름"
  value       = aws_kms_alias.k8s_key_alias.name
}

output "alias_arn" {
  description = "생성된 KMS 키 별칭의 ARN"
  value       = aws_kms_alias.k8s_key_alias.arn
}

output "tags" {
  description = "KMS 키에 적용된 모든 태그"
  value       = local.tags
}

# CloudWatch/CloudTrail 관련 출력
output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = var.enable_cloudtrail && length(aws_cloudwatch_log_group.kms_logs) > 0 ? aws_cloudwatch_log_group.kms_logs[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = var.enable_cloudtrail && length(aws_cloudwatch_log_group.kms_logs) > 0 ? aws_cloudwatch_log_group.kms_logs[0].arn : null
}

output "cloudtrail_name" {
  description = "CloudTrail 트레일 이름"
  value       = var.enable_cloudtrail && length(aws_cloudtrail.kms_trail) > 0 ? aws_cloudtrail.kms_trail[0].name : null
}

output "cloudtrail_arn" {
  description = "CloudTrail 트레일 ARN"
  value       = var.enable_cloudtrail && length(aws_cloudtrail.kms_trail) > 0 ? aws_cloudtrail.kms_trail[0].arn : null
}

output "s3_bucket_name" {
  description = "CloudTrail 로그를 저장하는 S3 버킷 이름"
  value       = var.enable_cloudtrail && length(aws_s3_bucket.kms_logs) > 0 ? aws_s3_bucket.kms_logs[0].id : null
}

output "s3_bucket_arn" {
  description = "CloudTrail 로그를 저장하는 S3 버킷 ARN"
  value       = var.enable_cloudtrail && length(aws_s3_bucket.kms_logs) > 0 ? aws_s3_bucket.kms_logs[0].arn : null
}

output "cloudwatch_alarm_name" {
  description = "KMS 키 사용량 CloudWatch 경보 이름"
  value       = var.enable_monitoring && length(aws_cloudwatch_metric_alarm.kms_key_usage) > 0 ? aws_cloudwatch_metric_alarm.kms_key_usage[0].alarm_name : null
}

output "cloudwatch_alarm_arn" {
  description = "KMS 키 사용량 CloudWatch 경보 ARN"
  value       = var.enable_monitoring && length(aws_cloudwatch_metric_alarm.kms_key_usage) > 0 ? aws_cloudwatch_metric_alarm.kms_key_usage[0].arn : null
}

# 재해 복구 관련 출력
output "replica_key_id" {
  description = "복제된 KMS 키의 ID"
  value       = var.enable_multi_region ? aws_kms_replica_key.replica[0].key_id : null
}

output "replica_key_arn" {
  description = "복제된 KMS 키의 ARN"
  value       = var.enable_multi_region ? aws_kms_replica_key.replica[0].arn : null
}

output "replica_alias_name" {
  description = "복제된 KMS 키의 별칭 이름"
  value       = var.enable_multi_region ? aws_kms_alias.replica_alias[0].name : null
}

output "backup_vault_name" {
  description = "AWS Backup 볼트 이름"
  value       = var.enable_backup ? aws_backup_vault.kms_backup[0].name : null
}

output "backup_vault_arn" {
  description = "AWS Backup 볼트 ARN"
  value       = var.enable_backup ? aws_backup_vault.kms_backup[0].arn : null
}

output "backup_plan_id" {
  description = "AWS Backup 계획 ID"
  value       = var.enable_backup ? aws_backup_plan.kms_backup[0].id : null
}

output "backup_plan_arn" {
  description = "AWS Backup 계획 ARN"
  value       = var.enable_backup ? aws_backup_plan.kms_backup[0].arn : null
}

output "replica_backup_vault_name" {
  description = "복제 리전의 AWS Backup 볼트 이름"
  value       = var.enable_multi_region && var.enable_backup ? aws_backup_vault.kms_backup_replica[0].name : null
}

output "replica_backup_vault_arn" {
  description = "복제 리전의 AWS Backup 볼트 ARN"
  value       = var.enable_multi_region && var.enable_backup ? aws_backup_vault.kms_backup_replica[0].arn : null
}

output "auto_recovery_function_name" {
  description = "자동 복구 Lambda 함수 이름"
  value       = var.enable_auto_recovery ? aws_lambda_function.auto_recovery[0].function_name : null
}

output "auto_recovery_function_arn" {
  description = "자동 복구 Lambda 함수 ARN"
  value       = var.enable_auto_recovery ? aws_lambda_function.auto_recovery[0].arn : null
} 