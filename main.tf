provider "aws" {
  region = var.aws_region
}

# 1. VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# 2. Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

# 3. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# 4. Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# 5. Route Table Association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# 6. Security Group (Allow SSH)
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

# 7. Generate SSH Key Pair (TLS)
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 8. AWS Key Pair from TLS
resource "aws_key_pair" "my_key" {
  key_name   = "my-keypair"
  public_key = tls_private_key.example.public_key_openssh
}

# 9. EC2 Instance
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

#################  This was added for flow logs but can be removed if not managing traffic withe the AWS onboarding or removed if doing the flow log access using the CLI,Console or CFT methods mentioned in the lab - NM 24th Aug 2025



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

# --- 15. Outputs ---
output "flow_logs_bucket" {
  value = aws_s3_bucket.flow_logs_bucket.id
}

output "flow_log_id" {
  value = aws_flow_log.vpc_flow_log.id
}

# --- 16. Generate local key file after provisioning ---
resource "local_file" "private_key_pem" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0600"
}

# --- 17. Null resource to ensure post-provision actions ---
resource "null_resource" "post_setup" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Private key saved at my-keypair.pem with 600 permissions"
    EOT
  }

  depends_on = [
    aws_instance.web,
    local_file.private_key_pem
  ]
}
