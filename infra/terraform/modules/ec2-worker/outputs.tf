output "public_ips" {
  description = "워커 노드들의 퍼블릭 IP 주소 목록"
  value       = aws_instance.worker[*].public_ip
}

output "private_ips" {
  description = "워커 노드들의 프라이빗 IP 주소 목록"
  value       = aws_instance.worker[*].private_ip
}

output "instance_ids" {
  description = "워커 노드들의 인스턴스 ID 목록"
  value       = aws_instance.worker[*].id
}

output "security_group_id" {
  description = "워커 노드들의 보안 그룹 ID"
  value       = aws_security_group.worker.id
}

output "worker_count" {
  description = "생성된 워커 노드 수"
  value       = length(aws_instance.worker)
} 