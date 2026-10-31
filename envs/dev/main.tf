# Image Debian 12 officielle la plus recente
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name = "novasphere-${var.environment}-${var.owner}"

  tags = {
    Project     = "NovaSphere"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}
