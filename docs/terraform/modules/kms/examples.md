# KMS 모듈 사용 예제

## 기본 사용법

```hcl
module "kms" {
  source = "../../modules/kms"

  project_name = "k8s-ec2-observability"
  environment  = "dev"
}
```

## 커스텀 태그 적용

```hcl
module "kms" {
  source = "../../modules/kms"

  project_name = "k8s-ec2-observability"
  environment  = "prod"
  
  tags = {
    Team        = "Platform"
    Cost-Center = "12345"
    Owner       = "platform-team"
  }
}
```

## 보안 강화 설정

```hcl
module "kms" {
  source = "../../modules/kms"

  project_name           = "k8s-ec2-observability"
  environment           = "prod"
  deletion_window_in_days = 30
  enable_key_rotation   = true
  
  tags = {
    Team        = "Security"
    Sensitivity = "High"
  }
}
```

## 테스트 환경 설정

```hcl
module "kms" {
  source = "../../modules/kms"

  project_name = "k8s-ec2-observability"
  environment  = "test"
  
  tags = {
    Team    = "DevOps"
    Purpose = "Testing"
  }
}
``` 