# VPC 모듈
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  availability_zone   = var.availability_zone
  vpc_cidr           = var.vpc_cidr
  tags               = local.common_tags
}

# 보안 그룹 모듈
module "security" {
  source = "./modules/security"

  project_name  = var.project_name
  vpc_id        = module.vpc.vpc_id
  ingress_rules = local.k8s_sg_ingress
  tags          = local.common_tags
}

# EC2 마스터 인스턴스
module "master" {
  source = "./modules/ec2-master"

  project_name        = var.project_name
  ami_id             = var.ami_id
  instance_type      = var.master_instance_type
  subnet_id          = module.vpc.public_subnet_id
  vpc_id             = module.vpc.vpc_id
  ssh_key_name       = var.key_name
  private_key_path   = var.private_key_path
  root_volume_size   = 30
  security_group_id  = module.security.security_group_id
  scripts_bucket     = "dummy-bucket"
  tags               = local.common_tags
}

# EC2 워커 인스턴스들
module "worker" {
  source = "./modules/ec2-worker"

  project_name             = var.project_name
  ami_id                  = var.ami_id
  instance_type           = var.node_instance_type
  worker_count            = var.worker_instance_count
  subnet_id               = module.vpc.private_subnet_id
  vpc_id                  = module.vpc.vpc_id
  ssh_key_name            = var.key_name
  private_key_path        = var.private_key_path
  root_volume_size        = 30
  master_private_ip       = module.master.private_ip
  master_public_ip        = module.master.public_ip
  master_instance         = module.master
  master_security_group_id = module.master.security_group_id
  scripts_bucket          = "dummy-bucket"
  tags                    = local.common_tags
} 