# provider 설정은 provider.tf로 이동

locals {
  common_tags = merge(var.default_tags, {
    Name = var.project_name
  })
}

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
  tags                     = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  aws_account_id    = var.aws_account_id
  trusted_role_arns = [var.terraform_user_arn]
  tags             = local.common_tags
} 