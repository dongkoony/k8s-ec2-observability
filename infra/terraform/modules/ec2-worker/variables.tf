variable "project_name" {
  description = "Project name"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "AMI ID for worker instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet ID where worker instances will be created"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
}

variable "master_private_ip" {
  description = "Private IP address of the master node"
  type        = string
}

variable "master_public_ip" {
  description = "Public IP address of the master node (for bastion)"
  type        = string
}

variable "master_instance" {
  description = "Master instance dependency"
  type        = any
}

variable "master_security_group_id" {
  description = "마스터 노드의 보안 그룹 ID"
  type        = string
}

variable "scripts_bucket" {
  description = "S3 bucket name containing setup scripts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
} 