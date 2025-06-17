output "public_ip" {
  description = "Master node public IP address"
  value       = aws_instance.master.public_ip
}

output "private_ip" {
  description = "Master node private IP address"
  value       = aws_instance.master.private_ip
}

output "instance_id" {
  description = "Master node instance ID"
  value       = aws_instance.master.id
}

output "security_group_id" {
  description = "Security group ID used by master node"
  value       = var.security_group_id
}

output "subnet_id" {
  description = "마스터 노드가 위치한 서브넷 ID"
  value       = aws_instance.master.subnet_id
}

output "availability_zone" {
  description = "마스터 노드의 가용영역"
  value       = aws_instance.master.availability_zone
} 