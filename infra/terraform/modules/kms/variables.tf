variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/stage/prod)"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

variable "deletion_window_in_days" {
  description = "KMS 키 삭제 대기 기간 (7-30일)"
  type        = number
  default     = 7

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "KMS 키 자동 교체 활성화 여부"
  type        = bool
  default     = true
}

variable "alias_name" {
  description = "KMS 키 별칭 이름"
  type        = string
  default     = null
} 