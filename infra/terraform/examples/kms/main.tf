# KMS 모듈 테스트를 위한 예제
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 기본 AWS provider
provider "aws" {
  region = var.region
}

module "kms" {
  source = "../../modules/kms"

  project_name         = var.project_name
  environment          = var.environment
  unique_id            = var.unique_id
  enable_multi_region  = var.enable_multi_region
  replica_region       = var.replica_region
  enable_backup        = var.enable_backup
  enable_auto_recovery = var.enable_auto_recovery
  enable_monitoring    = var.enable_monitoring
  enable_cloudtrail    = var.enable_cloudtrail
  tags                 = var.tags
} 