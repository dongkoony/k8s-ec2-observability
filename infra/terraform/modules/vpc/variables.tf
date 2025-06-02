variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/stage/prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block"
  }
}

variable "availability_zone" {
  description = "VPC 가용영역"
  type        = string
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  type        = string
  default     = null # CIDR이 지정되지 않으면 VPC CIDR에서 자동 계산

  validation {
    condition     = var.public_subnet_cidr == null ? true : can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block or null"
  }
}

variable "private_subnet_cidr" {
  description = "프라이빗 서브넷 CIDR 블록"
  type        = string
  default     = null # CIDR이 지정되지 않으면 VPC CIDR에서 자동 계산

  validation {
    condition     = var.private_subnet_cidr == null ? true : can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block or null"
  }
}

variable "enable_nat_gateway" {
  description = "NAT 게이트웨이 활성화 여부"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT 게이트웨이 사용 여부 (비용 절감용)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "모든 리소스에 적용할 태그"
  type        = map(string)
  default     = {} 
}