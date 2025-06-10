terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"

  # S3 백엔드 일시 비활성화 (테스트용)
  # backend "s3" {
  #   bucket         = "terraform-state-k8s-observability"
  #   key            = "terraform.tfstate"
  #   region         = "ap-northeast-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

provider "aws" {
  region = "ap-northeast-2"
  
  default_tags {
    tags = {
      Environment = terraform.workspace
      Project     = "k8s-observability"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
    }
  }
  
  # assume_role 일시 비활성화 (테스트용)
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.aws_account_id}:role/TerraformExecutionRole"
  # }
} 