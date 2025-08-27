###############################
#  Provider
###############################
provider "aws" {
  region = "us-east-1"
}

###############################
#  1. VPC
###############################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terraform-VPC"
  }
}

###############################
#  2. Subnet
###############################
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Terraform-Subnet"
  }
}

###############################
#  3. Internet Gateway
###############################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Terraform-IGW"
  }
}

###############################
#  4. Route Table
###############################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Terraform-Public-RouteTable"
  }
}

###############################
#  5. Route Table Association
###############################
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

###############################
#  6. Security Group (SSH)
###############################
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

  tags = {
    Name = "Terraform-SSH-SG"
  }
}

###############################
#  7. TLS Key Pair
###############################
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

###############################
#  8. AWS Key Pair
###############################
resource "aws_key_pair" "my_key" {
  key_name   = "my-keypair"
  public_key = tls_private_key.example.public_key_openssh
}

###############################
#  9. EC2 Instance
###############################
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

###############################
# 10. Random suffix for bucket
###############################
resource "random_id" "suffix" {
  byte_length = 4
}

###############################
# 11. KMS Key for Flow Logs
###############################
resource "aws_kms_key" "flow_logs_key" {
  description             = "KMS key for VPC Flow Logs in us-east-1"
  deletion_window_in_days = 7
}

###############################
# 12. S3 Bucket for Flow Logs
###############################
resource "aws_s3_bucket" "flow_logs_bucket" {
  bucket = "my-flow-logs-bucket-${random_id.suffix.hex}"
  acl    = "private"
  tags = {
    Name = "Terraform-FlowLogs-Bucket"
  }
}

###############################
# 13. Current AWS Account
###############################
data "aws_caller_identity" "current" {}

###############################
# 14. Bucket Policy for Flow Logs
###############################
resource "aws_s3_bucket_policy" "flow_logs_policy" {
  bucket = aws_s3_bucket.flow_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.flow_logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.flow_logs_bucket.arn
      }
    ]
  })
}

###############################
# 15. VPC Flow Log
###############################
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination      = aws_s3_bucket.flow_logs_bucket.arn
  log_destination_type = "s3"
  kms_key_id           = aws_kms_key.flow_logs_key.arn
  max_aggregation_interval = 60

  depends_on = [aws_s3_bucket_policy.flow_logs_policy]
}

###############################
# 16. Save private key locally
###############################
resource "local_file" "private_key_pem" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/my-keypair.pem"
  file_permission = "0600"
}

###############################
# 17. Post-provision message
###############################
resource "null_resource" "post_setup" {
  provisioner "local-exec" {
    command = "echo 'Private key saved at my-keypair.pem with 600 permissions'"
  }

  depends_on = [
    aws_instance.web,
    local_file.private_key_pem
  ]
}
