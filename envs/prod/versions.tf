terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      # 6.28 minimum : exige par les versions recentes du module VPC du registre.
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NovaSphere"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Environment = var.environment
    }
  }
}
