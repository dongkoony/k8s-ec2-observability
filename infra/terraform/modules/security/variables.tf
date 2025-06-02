variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ingress_rules" {
  description = "인바운드 규칙 목록"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    self            = optional(bool)
    security_groups = optional(list(string))
    description     = optional(string)
  }))
}

variable "egress_rules" {
  description = "아웃바운드 규칙 목록"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    self            = optional(bool)
    security_groups = optional(list(string))
    description     = optional(string)
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
} 