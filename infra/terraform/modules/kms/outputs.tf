output "key_id" {
  description = "KMS 키 ID"
  value       = aws_kms_key.k8s_key.key_id
}

output "key_arn" {
  description = "KMS 키 ARN"
  value       = aws_kms_key.k8s_key.arn
}

output "alias_arn" {
  description = "KMS 키 별칭 ARN"
  value       = aws_kms_alias.k8s_key_alias.arn
}

output "alias_name" {
  description = "KMS 키 별칭 이름"
  value       = aws_kms_alias.k8s_key_alias.name
} 