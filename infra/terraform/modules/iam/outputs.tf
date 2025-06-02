output "terraform_execution_role_arn" {
  description = "Terraform 실행 역할의 ARN"
  value       = aws_iam_role.terraform_execution_role.arn
}

output "terraform_execution_role_name" {
  description = "Terraform 실행 역할의 이름"
  value       = aws_iam_role.terraform_execution_role.name
}

output "kms_management_policy_arn" {
  description = "KMS 관리 정책의 ARN"
  value       = aws_iam_policy.kms_management_policy.arn
} 