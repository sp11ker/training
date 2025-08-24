provider "aws" {
  region = "eu-north-1"
}

# --- 1. VPC ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# --- 2. Subnet ---
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

# --- 3. Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# --- 4. Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# --- 5. Route Table Association ---
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# --- 6. Security Group (SSH) ---
resource "aws_security_group" "ssh" {
  name        = "my-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 7. Generate TLS Key ---
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- 8. Save private key locally ---
resource "local_file" "private_key_pem" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0600"
}

# --- 9. AWS Key Pair ---
resource "aws_key_pair" "my_key" {
  key_name   = "my-keypair"
  public_key = tls_private_key.example.public_key_openssh
}

# --- 10. EC2 Instance ---
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t3.nano"
  subnet_id              = aws_subnet.main.id
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]

  tags = {
    Name = "Terraform-EC2"
  }
}

# --- 11. Random Suffix for Unique Bucket ---
resource "random_id" "suffix" {
  byte_length = 4
}

# --- 12. S3 Bucket for Flow Logs (unencrypted) ---
resource "aws_s3_bucket" "flow_logs_bucket" {
  bucket = "my-flow-logs-bucket-${random_id.suffix.hex}"
}

# --- 13. Current AWS Account ID ---
data "aws_caller_identity" "current" {}

# --- 14. Bucket Policy for VPC Flow Logs ---
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

provider "aws" {
  region = "eu-north-1"
}

# --- 1. VPC ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# --- 2. Subnet ---
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

# --- 3. Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# --- 4. Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# --- 5. Route Table Association ---
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# --- 6. Security Group (SSH) ---
resource "aws_security_group" "ssh" {
  name        = "my-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 7. Generate TLS Key ---
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- 8. Save private key locally ---
resource "local_file" "private_key_pem" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0600"
}

# --- 9. AWS Key Pair ---
resource "aws_key_pair" "my_key" {
  key_name   = "my-keypair"
  public_key = tls_private_key.example.public_key_openssh
}

# --- 10. EC2 Instance ---
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t3.nano"
  subnet_id              = aws_subnet.main.id
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]

  tags = {
    Name = "Terraform-EC2"
  }
}

# --- 11. Random Suffix for Unique Bucket ---
resource "random_id" "suffix" {
  byte_length = 4
}

# --- 12. S3 Bucket for Flow Logs ---
resource "aws_s3_bucket" "flow_logs_bucket" {
  bucket = "my-flow-logs-bucket-${random_id.suffix.hex}"
}

# --- 13. Current AWS Account ID ---
data "aws_caller_identity" "current" {}

# --- 14. Bucket Policy for VPC Flow Logs ---
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

# --- 15. IAM Role for VPC Flow Logs ---
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# --- 16. IAM Role Policy for S3 access ---
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl"
        ],
        Resource = [
          "${aws_s3_bucket.flow_logs_bucket.arn}/*",
          aws_s3_bucket.flow_logs_bucket.arn
        ]
      }
    ]
  })
}

# --- 17. VPC Flow Log ---
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination      = aws_s3_bucket.flow_logs_bucket.arn
  log_destination_type = "s3"
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
  log_format           = "version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status"
  max_aggregation_interval = 600

  depends_on = [aws_s3_bucket_policy.flow_logs_policy]
}

# --- Outputs ---
output "private_key_path" {
  value = local_file.private_key_pem.filename
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "flow_logs_bucket" {
  value = aws_s3_bucket.flow_logs_bucket.id
}

output "flow_log_id" {
  value = aws_flow_log.vpc_flow_log.id
}


# --- 17. VPC Flow Log ---
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination      = aws_s3_bucket.flow_logs_bucket.arn
  log_destination_type = "s3"
  log_format           = "version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status"
  max_aggregation_interval = 600

  depends_on = [aws_s3_bucket_policy.flow_logs_policy]
}

# --- Outputs ---
output "private_key_path" {
  value = local_file.private_key_pem.filename
}

output "flow_logs_bucket" {
  value = aws_s3_bucket.flow_logs_bucket.id
}

output "flow_log_id" {
  value = aws_flow_log.vpc_flow_log.id
}
