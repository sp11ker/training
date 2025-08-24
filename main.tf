# --- 10. Random suffix for unique bucket name ---
resource "random_id" "suffix" {
  byte_length = 4
}

# --- 11. S3 Bucket for VPC Flow Logs (unencrypted) ---
resource "aws_s3_bucket" "flow_logs_bucket" {
  bucket = "my-flow-logs-bucket-${random_id.suffix.hex}"
  acl    = "private"
}

# --- 12. Current AWS Account ID ---
data "aws_caller_identity" "current" {}

# --- 13. Bucket Policy to allow VPC Flow Logs service to write logs ---
resource "aws_s3_bucket_policy" "flow_logs_policy" {
  bucket = aws_s3_bucket.flow_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.flow_logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.flow_logs_bucket.arn
      }
    ]
  })
}

# --- 14. VPC Flow Log ---
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination      = aws_s3_bucket.flow_logs_bucket.arn
  log_destination_type = "s3"

  # S3 flow logs do not allow custom log_format; AWS uses the standard format automatically
  max_aggregation_interval = 600

  depends_on = [aws_s3_bucket_policy.flow_logs_policy]
}

# --- Outputs ---
output "flow_logs_bucket" {
  value = aws_s3_bucket.flow_logs_bucket.id
}

output "flow_log_id" {
  value = aws_flow_log.vpc_flow_log.id
}
