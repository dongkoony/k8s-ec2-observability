# VPC 출력
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.vpc.private_subnet_id
}

# EC2 출력
output "master_public_ip" {
  description = "Master node public IP"
  value       = module.master.public_ip
}

output "master_private_ip" {
  description = "Master node private IP"
  value       = module.master.private_ip
}

output "worker_private_ips" {
  description = "Worker nodes private IPs"
  value       = module.worker.private_ips
}

output "security_group_id" {
  description = "생성된 보안 그룹 ID"
  value       = module.security.security_group_id
} 