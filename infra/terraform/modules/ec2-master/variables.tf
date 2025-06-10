variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "ami_id" {
  description = "EC2 인스턴스 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
}

variable "subnet_id" {
  description = "EC2 인스턴스가 생성될 서브넷 ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssh_key_name" {
  description = "EC2 접속용 SSH 키 이름"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

variable "root_volume_size" {
  description = "루트 볼륨 크기(GB)"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "EBS 볼륨 암호화용 KMS 키 ID"
  type        = string
  default     = ""
} 