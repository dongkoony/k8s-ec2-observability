output "security_group_id" {
  description = "생성된 보안 그룹 ID"
  value       = aws_security_group.k8s_sg.id
}

output "security_group_name" {
  description = "생성된 보안 그룹 이름"
  value       = aws_security_group.k8s_sg.name
} 