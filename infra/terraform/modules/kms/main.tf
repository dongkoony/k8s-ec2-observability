terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

locals {
  # 기본 태그 정의
  default_tags = {
    Name        = "${var.project_name}-kms-key"
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
    Team        = "DevOps"  # 기본 Team 태그 추가
  }
  
  # 사용자 정의 태그와 기본 태그 병합 (사용자 정의 태그 우선)
  tags = merge(var.tags, local.default_tags)
}

data "aws_caller_identity" "current" {}

# CloudWatch 로그 그룹 생성 (CloudTrail 활성화시에만)
resource "aws_cloudwatch_log_group" "kms_logs" {
  count = var.enable_cloudtrail ? 1 : 0

  name              = "/aws/kms/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

# CloudTrail 트레일 생성 (CloudTrail 활성화시에만)
resource "aws_cloudtrail" "kms_trail" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.project_name}-${var.environment}-kms-trail"
  s3_bucket_name               = aws_s3_bucket.kms_logs[0].id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.kms_logs[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role[0].arn

  tags = local.tags
}

# CloudTrail 로그를 저장할 S3 버킷 (CloudTrail 활성화시에만)
resource "aws_s3_bucket" "kms_logs" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket        = "${var.project_name}-${var.environment}-kms-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "prod"

  tags = local.tags
}

# S3 버킷 버전 관리 활성화
resource "aws_s3_bucket_versioning" "kms_logs" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.kms_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 서버 측 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "kms_logs" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.kms_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudTrail이 CloudWatch Logs에 로그를 전송하기 위한 IAM 역할
resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# CloudTrail이 CloudWatch Logs에 로그를 전송하기 위한 IAM 정책
resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.kms_logs[0].arn}:*"
      }
    ]
  })
}

# S3 버킷 정책 - CloudTrail 로그 저장 허용
resource "aws_s3_bucket_policy" "kms_logs" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.kms_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.kms_logs[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.kms_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# KMS 키 생성
resource "aws_kms_key" "k8s_key" {
  description             = "${var.project_name}-key"
  deletion_window_in_days = var.environment == "prod" ? 30 : (var.environment == "stage" ? 14 : 7)
  enable_key_rotation     = var.enable_key_rotation
  
  # 병합된 태그 적용
  tags = local.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Key Administrators"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-developer"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS 키 별칭 생성
resource "aws_kms_alias" "k8s_key_alias" {
  name          = var.unique_id != "" ? "alias/${var.project_name}-${var.environment}-${var.unique_id}-key" : "alias/${var.project_name}-${var.environment}-key"
  target_key_id = aws_kms_key.k8s_key.key_id
}

# CloudWatch 메트릭 알람 (모니터링 활성화시에만)
resource "aws_cloudwatch_metric_alarm" "kms_key_usage" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-kms-key-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfRequestsSucceeded"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.key_usage_threshold
  alarm_description   = "This metric monitors KMS key usage"
  alarm_actions       = var.alarm_actions

  dimensions = {
    KeyId = aws_kms_key.k8s_key.key_id
  }

  tags = local.tags
}

# 다중 리전 복제 키 (선택적)
resource "aws_kms_replica_key" "replica" {
  count = var.enable_multi_region ? 1 : 0

  description             = "${var.project_name}-replica-key"
  primary_key_arn        = aws_kms_key.k8s_key.arn
  deletion_window_in_days = var.environment == "prod" ? 30 : (var.environment == "stage" ? 14 : 7)
  
  tags = merge(local.tags, {
    IsReplica = "true"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# 복제 키 별칭
resource "aws_kms_alias" "replica_alias" {
  count = var.enable_multi_region ? 1 : 0

  name          = var.replica_alias_name != null ? var.replica_alias_name : "alias/${var.project_name}-${var.environment}-replica-key"
  target_key_id = aws_kms_replica_key.replica[0].key_id
}



# AWS Backup 볼트
resource "aws_backup_vault" "kms_backup" {
  count = var.enable_backup ? 1 : 0

  name        = "${var.project_name}-${var.environment}-kms-backup"
  kms_key_arn = aws_kms_key.k8s_key.arn
  tags        = local.tags
}

# AWS Backup 계획
resource "aws_backup_plan" "kms_backup" {
  count = var.enable_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-kms-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.kms_backup[0].name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }

    dynamic "copy_action" {
      for_each = var.enable_multi_region && var.enable_backup ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.kms_backup_replica[0].arn
      }
    }
  }

  tags = local.tags
}

# 복제 리전의 백업 볼트
resource "aws_backup_vault" "kms_backup_replica" {
  count = var.enable_multi_region && var.enable_backup ? 1 : 0

  name        = "${var.project_name}-${var.environment}-kms-backup-replica"
  kms_key_arn = var.enable_multi_region ? aws_kms_replica_key.replica[0].arn : aws_kms_key.k8s_key.arn
  tags        = local.tags
}

# 자동 복구 Lambda 함수
resource "aws_lambda_function" "auto_recovery" {
  count = var.enable_auto_recovery ? 1 : 0

  filename         = data.archive_file.lambda_zip[0].output_path
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256
  function_name    = "${var.project_name}-${var.environment}-kms-auto-recovery"
  role            = aws_iam_role.lambda_role[0].arn
  handler         = "auto_recovery.handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      KMS_KEY_ID        = aws_kms_key.k8s_key.key_id
      BACKUP_VAULT_NAME = var.enable_backup && length(aws_backup_vault.kms_backup) > 0 ? aws_backup_vault.kms_backup[0].name : ""
      ENVIRONMENT       = var.environment
    }
  }

  tags = local.tags
}

# Lambda 함수 코드 압축
data "archive_file" "lambda_zip" {
  count = var.enable_auto_recovery ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/functions"
  output_path = "${path.module}/functions/auto_recovery.zip"
}

# Lambda 실행 역할
resource "aws_iam_role" "lambda_role" {
  count = var.enable_auto_recovery ? 1 : 0

  name = "${var.project_name}-${var.environment}-lambda-recovery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Lambda 정책
resource "aws_iam_role_policy" "lambda_policy" {
  count = var.enable_auto_recovery ? 1 : 0

  name = "${var.project_name}-${var.environment}-lambda-recovery-policy"
  role = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:EnableKey",
          "kms:DisableKey",
          "backup:StartRestoreJob",
          "backup:DescribeRestoreJob"
        ]
        Resource = [
          aws_kms_key.k8s_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch 이벤트 규칙
resource "aws_cloudwatch_event_rule" "key_state_change" {
  count = var.enable_auto_recovery ? 1 : 0

  name        = "${var.project_name}-${var.environment}-kms-state-change"
  description = "KMS 키 상태 변경 감지"

  event_pattern = jsonencode({
    source      = ["aws.kms"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["kms.amazonaws.com"]
      eventName   = ["DisableKey", "ScheduleKeyDeletion"]
    }
  })

  tags = local.tags
}

# CloudWatch 이벤트 대상
resource "aws_cloudwatch_event_target" "lambda" {
  count = var.enable_auto_recovery ? 1 : 0

  rule      = aws_cloudwatch_event_rule.key_state_change[0].name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.auto_recovery[0].arn
}

# Lambda 권한
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_auto_recovery ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_recovery[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.key_state_change[0].arn
} 