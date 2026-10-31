# Le module d'equipe (depot terraform-aws-web), appele par tag : une version = un tag, jamais modifie apres publication.
module "web" {
  #checkov:skip=CKV_TF_1:source git epinglee par tag de version (v1.0.0), pas par hash : choix de lisibilite pour l equipe ; le tag n est jamais deplace
  source = "git::https://github.com/Pengchao020401/terraform-aws-web.git?ref=v1.0.1"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnets
  ami_id            = data.aws_ami.debian.id
  instance_type     = var.instance_type
  min_size          = var.min_size
  max_size          = var.max_size
  desired_capacity  = var.desired_capacity

  # Learner Lab : pas de creation de role IAM, on utilise le profil existant.
  # Hors lab : aws_iam_role + aws_iam_instance_profile dans secrets.tf (voir le cahier des charges).
  instance_profile_name = "LabInstanceProfile"

  # bootstrap.sh : 10 lignes max, AUCUN secret dedans (il lit le parametre SSM au demarrage).
  user_data = templatefile("${path.module}/bootstrap.sh", {
    environment = var.environment
    region      = var.aws_region
  })

  tags = local.tags

  # Les serveurs lisent le secret des leur demarrage : le parametre SSM doit donc exister avant eux.
  depends_on = [aws_ssm_parameter.db_password]
}
