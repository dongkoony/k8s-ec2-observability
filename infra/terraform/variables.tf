variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/stage/prod)"
  type        = string
}

variable "availability_zone" {
  description = "AWS 가용영역"
  type        = string
}

variable "master_instance_type" {
  description = "마스터 노드 인스턴스 타입"
  type        = string
}

variable "node_instance_type" {
  description = "워커 노드 인스턴스 타입"
  type        = string
}

variable "worker_instance_count" {
  description = "워커 노드 수"
  type        = number
}

variable "ami_id" {
  description = "EC2 인스턴스 AMI ID"
  type        = string
}

variable "key_name" {
  description = "EC2 키 페어 이름"
  type        = string
}

variable "private_key_path" {
  description = "EC2 접속용 프라이빗 키 경로"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  
  validation {
    condition     = can(regex("^\\d{12}$", var.account_id))
    error_message = "AWS account ID must be 12 digits."
  }
}

variable "aws_account_id" {
  description = "AWS 계정 ID"
  type        = string
}

variable "terraform_user_arn" {
  description = "Terraform을 실행하는 IAM 사용자의 ARN"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "default_tags" {
  description = "모든 리소스에 적용될 기본 태그"
  type        = map(string)
  default     = {}
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
} 