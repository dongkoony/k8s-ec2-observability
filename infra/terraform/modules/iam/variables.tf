variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/stage/prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS 계정 ID"
  type        = string
}

variable "trusted_role_arns" {
  description = "역할을 위임할 수 있는 신뢰할 수 있는 IAM ARN 목록"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS 키 ARN (EC2 인스턴스 암호화용)"
  type        = string
  default     = ""
} 