# VPC du registre public : deux zones, subnets publics, pas de NAT Gateway (facturee a l'heure).
module "vpc" {
  #checkov:skip=CKV_TF_1:module du registre public epingle par version (~> 6.7) ; le hash de commit ne s applique qu aux sources git
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = var.vpc_cidr

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true # sans IP publique, pas de sortie Internet donc pas d'installation de nginx
}
