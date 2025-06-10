# provider 설정은 provider.tf로 이동

# locals는 locals.tf에서 정의됨

module "vpc" {
  source = "./modules/vpc"

  project_name      = var.project_name
  environment       = var.environment
  availability_zone = var.availability_zone
  vpc_cidr          = var.vpc_cidr
  tags              = local.common_tags
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  ingress_rules = local.k8s_sg_ingress
  tags         = local.common_tags
}

module "master" {
  source = "./modules/ec2-master"

  project_name    = var.project_name
  ami_id         = var.ami_id
  instance_type  = var.master_instance_type
  subnet_id      = module.vpc.public_subnet_id
  vpc_id         = module.vpc.vpc_id
  ssh_key_name   = var.key_name
  kms_key_id     = module.kms.key_id  # KMS 키 ID 전달
  tags           = local.common_tags
}

module "worker" {
  source = "./modules/ec2-worker"

  project_name              = var.project_name
  worker_count             = var.worker_instance_count
  ami_id                   = var.ami_id
  instance_type            = var.node_instance_type
  subnet_id                = module.vpc.private_subnet_id
  vpc_id                   = module.vpc.vpc_id
  ssh_key_name             = var.key_name
  master_private_ip        = module.master.private_ip
  master_security_group_id = module.master.security_group_id
  kms_key_id               = module.kms.key_id  # KMS 키 ID 전달
  tags                     = local.common_tags
}

# KMS 모듈 - 암호화 키 관리
module "kms" {
  source = "./modules/kms"

  project_name         = var.project_name
  environment          = var.environment
  enable_key_rotation  = var.enable_kms_key_rotation
  enable_multi_region  = var.enable_kms_multi_region
  enable_backup        = var.enable_kms_backup
  enable_auto_recovery = var.enable_kms_auto_recovery
  enable_monitoring    = var.enable_kms_monitoring
  enable_cloudtrail    = var.enable_kms_cloudtrail
  replica_region       = var.kms_replica_region
  tags                 = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  aws_account_id    = var.aws_account_id
  trusted_role_arns = [var.terraform_user_arn]
  kms_key_arn       = module.kms.key_arn  # KMS 키 ARN 전달
  tags             = local.common_tags
} 