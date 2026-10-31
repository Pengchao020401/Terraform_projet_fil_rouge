# Secret applicatif : mot de passe stocke dans SSM Parameter Store (SecureString).
# Il n'est JAMAIS ecrit dans le code, le state, le plan, bootstrap.sh ni les logs :
#   - variable "ephemeral" : Terraform ne la persiste ni dans le state ni dans le plan ;
#   - value_wo (write-only) : la valeur part vers AWS mais n'est pas enregistree dans le state.
# On la fournit par l'environnement : export TF_VAR_db_password (voir SECURITE.md).

variable "db_password" {
  description = "Mot de passe applicatif, fourni par TF_VAR_db_password (jamais dans un fichier)"
  type        = string
  sensitive   = true
  ephemeral = true
  # PAS de valeur par defaut : sans TF_VAR_db_password, Terraform refuse de continuer.

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Le mot de passe doit contenir au moins 12 caracteres."
  }
}

variable "db_password_version" {
  description = "Numero de version du secret : l'incrementer pour faire tourner le mot de passe (value_wo n'est pas comparee)"
  type        = number
  default     = 1

  validation {
    condition     = var.db_password_version >= 1 && floor(var.db_password_version) == var.db_password_version
    error_message = "db_password_version doit etre un entier superieur ou egal a 1."
  }
}

resource "aws_ssm_parameter" "db_password" {
  #checkov:skip=CKV_AWS_337:Cle KMS geree par AWS (alias aws/ssm) au lieu d une cle CMK : creer une CMK ajoute un cout et un droit KMS que le Learner Lab ne garantit pas ; le secret reste chiffre au repos
  name             = "/novasphere/${var.environment}/db_password"
  description      = "Mot de passe applicatif NovaSphere ${var.environment} (ecrit en value_wo, absent du state)"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = var.db_password_version

  tags = local.tags
}

# Learner Lab : on ne cree PAS de role IAM (interdit). Les instances utilisent LabInstanceProfile (voir web.tf).
# Hors lab, on creerait ici aws_iam_role + aws_iam_role_policy + aws_iam_instance_profile :
# la politique ideale (ssm:GetParameter sur ce seul parametre) est documentee dans SECURITE.md.
