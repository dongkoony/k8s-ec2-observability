output "master_public_ip" {
  description = "마스터 노드의 퍼블릭 IP"
  value       = module.master.public_ip
}

output "master_private_ip" {
  description = "마스터 노드의 프라이빗 IP"
  value       = module.master.private_ip
}

output "worker_public_ips" {
  description = "워커 노드들의 퍼블릭 IP 목록"
  value       = module.worker.public_ips
}

output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "생성된 퍼블릭 서브넷 ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "생성된 프라이빗 서브넷 ID"
  value       = module.vpc.private_subnet_id
}

output "security_group_id" {
  description = "생성된 보안 그룹 ID"
  value       = module.security.security_group_id
} 