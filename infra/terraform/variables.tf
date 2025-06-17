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

variable "aws_account_id" {
  description = "AWS 계정 ID"
  type        = string
  
  validation {
    condition     = can(regex("^\\d{12}$", var.aws_account_id))
    error_message = "AWS account ID는 12자리 숫자여야 합니다."
  }
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

# KMS 관련 변수들
variable "enable_kms_key_rotation" {
  description = "KMS 키 자동 로테이션 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_kms_multi_region" {
  description = "KMS 멀티 리전 복제 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_kms_backup" {
  description = "KMS 백업 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_kms_auto_recovery" {
  description = "KMS 자동 복구 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_kms_monitoring" {
  description = "KMS 모니터링 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_kms_cloudtrail" {
  description = "KMS CloudTrail 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "kms_replica_region" {
  description = "KMS 키 복제 대상 리전"
  type        = string
  default     = "us-west-2"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

 