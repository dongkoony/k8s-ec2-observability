variable "project_name" {
  description = "프로젝트 이름 (예: k8s-ec2-observability)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/stage/prod/test)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod", "test"], var.environment)
    error_message = "환경은 'dev', 'stage', 'prod', 'test' 중 하나여야 합니다."
  }
}

variable "tags" {
  description = "리소스에 적용할 태그 (기본 태그 외 추가 태그)"
  type        = map(string)
  default     = {
    "Terraform" = "true"
  }
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

variable "enable_key_rotation" {
  description = "KMS 키 자동 교체 활성화 여부 (보안 강화를 위해 기본값 true)"
  type        = bool
  default     = true
}

variable "alias_name" {
  description = "KMS 키 별칭 이름 (null일 경우 project_name으로 자동 생성)"
  type        = string
  default     = null
  validation {
    condition     = var.alias_name == null || can(regex("^alias/", var.alias_name))
    error_message = "별칭은 'alias/'로 시작해야 합니다."
  }
}

# CloudWatch/CloudTrail 관련 변수
variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "유효하지 않은 로그 보관 기간입니다. AWS CloudWatch가 지원하는 값 중 하나를 선택하세요."
  }
}

variable "key_usage_threshold" {
  description = "KMS 키 사용량 경보 임계값"
  type        = number
  default     = 1000
}

variable "alarm_actions" {
  description = "CloudWatch 경보 발생 시 실행할 작업 (SNS 주제 ARN 목록)"
  type        = list(string)
  default     = []
}

# 재해 복구 관련 변수
variable "enable_multi_region" {
  description = "다중 리전 복제 활성화 여부"
  type        = bool
  default     = false
}

variable "replica_alias_name" {
  description = "복제 키의 별칭 이름 (null일 경우 project_name으로 자동 생성)"
  type        = string
  default     = null
  validation {
    condition     = var.replica_alias_name == null || can(regex("^alias/", var.replica_alias_name))
    error_message = "별칭은 'alias/'로 시작해야 합니다."
  }
}

variable "enable_backup" {
  description = "AWS Backup 활성화 여부"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "백업 스케줄 (cron 표현식)"
  type        = string
  default     = "cron(0 0 * * ? *)" # 매일 자정
}

variable "backup_retention_days" {
  description = "백업 보관 기간 (일)"
  type        = number
  default     = 30
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "백업 보관 기간은 1일에서 365일 사이여야 합니다."
  }
}

variable "enable_auto_recovery" {
  description = "자동 복구 기능 활성화 여부"
  type        = bool
  default     = true
}

variable "replica_region" {
  description = "복제 리전 (다중 리전 복제 시 사용)"
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}

variable "enable_monitoring" {
  description = "CloudWatch 모니터링 및 경보 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "CloudTrail 및 관련 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "unique_id" {
  description = "테스트용 고유 ID (선택적)"
  type        = string
  default     = ""
} 