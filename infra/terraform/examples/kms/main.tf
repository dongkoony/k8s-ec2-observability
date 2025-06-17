# KMS 모듈 테스트를 위한 예제 (GitHub Actions 최적화)
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

  project_name            = var.project_name
  environment             = var.environment
  unique_id               = var.unique_id
  enable_key_rotation     = var.enable_key_rotation
  deletion_window_in_days = var.deletion_window_in_days
  
  # 테스트 최적화: 복잡한 기능들 모두 비활성화
  enable_multi_region     = false  # 복제본 생성 비활성화
  replica_region          = null   # 복제본 리전 비활성화
  enable_backup           = false  # 백업 볼트 비활성화
  enable_auto_recovery    = false  # Lambda 자동 복구 비활성화
  enable_monitoring       = false  # CloudWatch 모니터링 비활성화
  enable_cloudtrail       = false  # CloudTrail 로깅 비활성화
  
  tags = var.tags
} 