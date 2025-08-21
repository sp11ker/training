output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

resource "local_file" "private_key" {
  content  = tls_private_key.example.private_key_pem
  filename = "${path.module}/my-keypair.pem"
  file_permission = "0400"
}
