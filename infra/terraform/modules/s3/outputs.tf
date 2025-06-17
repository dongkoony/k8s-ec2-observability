output "scripts_bucket_name" {
  description = "Name of the S3 bucket containing scripts"
  value       = aws_s3_bucket.scripts_bucket.id
}

output "scripts_bucket_arn" {
  description = "ARN of the S3 bucket containing scripts"
  value       = aws_s3_bucket.scripts_bucket.arn
} 