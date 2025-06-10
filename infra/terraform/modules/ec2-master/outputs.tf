output "public_ip" {
  description = "마스터 노드의 퍼블릭 IP 주소"
  value       = aws_instance.master.public_ip
}

output "private_ip" {
  description = "마스터 노드의 프라이빗 IP 주소"
  value       = aws_instance.master.private_ip
}

output "instance_id" {
  description = "마스터 노드의 인스턴스 ID"
  value       = aws_instance.master.id
}

output "security_group_id" {
  description = "마스터 노드의 보안 그룹 ID"
  value       = aws_security_group.master.id
}

output "subnet_id" {
  description = "마스터 노드가 위치한 서브넷 ID"
  value       = aws_instance.master.subnet_id
}

output "availability_zone" {
  description = "마스터 노드의 가용영역"
  value       = aws_instance.master.availability_zone
} 