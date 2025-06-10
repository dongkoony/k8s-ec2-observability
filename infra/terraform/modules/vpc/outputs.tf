output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.k8s_vpc.id
}

output "vpc_cidr" {
  description = "VPC의 CIDR 블록"
  value       = aws_vpc.k8s_vpc.cidr_block
}

output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = aws_subnet.public_subnet.id
}

output "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  value       = aws_subnet.public_subnet.cidr_block
}

output "private_subnet_id" {
  description = "프라이빗 서브넷 ID"
  value       = aws_subnet.private_subnet.id
}

output "private_subnet_cidr" {
  description = "프라이빗 서브넷 CIDR 블록"
  value       = aws_subnet.private_subnet.cidr_block
}

output "nat_gateway_id" {
  description = "NAT 게이트웨이 ID"
  value       = aws_nat_gateway.k8s_nat.id
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.k8s_igw.id
}
