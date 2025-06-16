variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "k8s-ec2-observability"
}

variable "environment" {
  description = "환경 (dev/stage/prod/test)"
  type        = string
  default     = "test"
}

variable "unique_id" {
  description = "고유 식별자"
  type        = string
}

variable "test_name" {
  description = "테스트 이름"
  type        = string
}

variable "enable_key_rotation" {
  description = "KMS 키 자동 교체 활성화 여부"
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "KMS 키 삭제 대기 기간 (7-30일)"
  type        = number
  default     = 7

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "삭제 대기 기간은 7일에서 30일 사이여야 합니다."
  }
}

variable "enable_multi_region" {
  description = "다중 리전 복제 활성화 여부"
  type        = bool
  default     = false
}

variable "replica_region" {
  description = "복제 리전"
  type        = string
  default     = "us-west-2"
}

variable "enable_backup" {
  description = "AWS Backup 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_auto_recovery" {
  description = "자동 복구 기능 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "CloudWatch 모니터링 및 경보 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "CloudTrail 및 관련 로깅 활성화 여부"
  type        = bool
  default     = false
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "k8s-ec2-observability"
    ManagedBy   = "terraform"
  }
} 