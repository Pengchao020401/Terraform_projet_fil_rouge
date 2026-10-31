# VPC du registre public : deux zones, subnets publics, pas de NAT Gateway (facturee a l'heure).
module "vpc" {
  #checkov:skip=CKV_AWS_130:IP publique voulue : sans NAT Gateway (facturee a l heure), les instances ont besoin d une IP publique pour installer nginx ; l acces entrant reste ferme par les groupes de securite
  #checkov:skip=CKV2_AWS_12:Faux positif : le module adopte le groupe de securite par defaut (manage_default_security_group = true) et le vide (aucune regle) ; checkov ne voit pas cette ressource conditionnelle du module
  #checkov:skip=CKV_TF_1:module du registre public epingle par version (~> 6.7) ; le hash de commit ne s applique qu aux sources git
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = var.vpc_cidr

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]

  enable_nat_gateway = false
  # Groupe de securite par defaut du VPC : adopte et vide (aucune regle).
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  map_public_ip_on_launch = true # sans IP publique, pas de sortie Internet donc pas d'installation de nginx
}
