output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC의 CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_id" {
  description = "프라이빗 서브넷 ID"
  value       = aws_subnet.private.id
}

output "private_subnet_cidr" {
  description = "프라이빗 서브넷 CIDR 블록"
  value       = aws_subnet.private.cidr_block
}

output "nat_gateway_id" {
  description = "NAT 게이트웨이 ID"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.main.id
}
