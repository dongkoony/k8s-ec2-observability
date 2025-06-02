# Terraform 실행 역할
resource "aws_iam_role" "terraform_execution_role" {
  name = "Terraform-Execution-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_role_arns
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-terraform-execution-role"
    Environment = var.environment
  })
}

# KMS 관리 정책
resource "aws_iam_policy" "kms_management_policy" {
  name        = "${var.project_name}-kms-management-policy"
  description = "KMS 키 관리를 위한 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyRotationStatus",
          "kms:ListResourceTags",
          "kms:ScheduleKeyDeletion",
          "kms:ListKeys",
          "kms:ListAliases"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-kms-management-policy"
    Environment = var.environment
  })
}

# KMS 정책 연결
resource "aws_iam_role_policy_attachment" "kms_policy_attachment" {
  role       = aws_iam_role.terraform_execution_role.name
  policy_arn = aws_iam_policy.kms_management_policy.arn
}

# 기본 관리자 정책 연결
resource "aws_iam_role_policy_attachment" "admin_policy_attachment" {
  role       = aws_iam_role.terraform_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
} 