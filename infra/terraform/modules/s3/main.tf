# S3 버킷 생성 (스크립트 저장용)
resource "aws_s3_bucket" "scripts_bucket" {
  bucket = "${var.project_name}-scripts-${random_string.bucket_suffix.result}"

  tags = var.tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# 버킷 버전 관리
resource "aws_s3_bucket_versioning" "scripts_versioning" {
  bucket = aws_s3_bucket.scripts_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "scripts_encryption" {
  bucket = aws_s3_bucket.scripts_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# combined_settings.sh 업로드
resource "aws_s3_object" "combined_settings_script" {
  bucket = aws_s3_bucket.scripts_bucket.id
  key    = "scripts/combined_settings.sh"
  source = "${path.root}/../../scripts/combined_settings.sh"
  etag   = filemd5("${path.root}/../../scripts/combined_settings.sh")

  tags = var.tags
}

# worker_setup.sh 업로드
resource "aws_s3_object" "worker_setup_script" {
  bucket = aws_s3_bucket.scripts_bucket.id
  key    = "scripts/worker_setup.sh"
  source = "${path.root}/../../scripts/worker_setup.sh"
  etag   = filemd5("${path.root}/../../scripts/worker_setup.sh")

  tags = var.tags
} 