variable "aws_region" {
  description = "Region AWS de deploiement (Learner Lab : us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Trigramme de l'etudiant, utilise pour nommer et tagger les ressources"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{3}$", var.owner))
    error_message = "Le trigramme doit etre compose de 3 lettres minuscules."
  }
}

variable "environment" {
  description = "Nom de l'environnement : dev ou prod"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir dev ou prod."
  }
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC (differente en dev et en prod)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr doit etre un CIDR valide, par exemple 10.0.0.0/16."
  }
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Nombre minimum d'instances (2 au moins)"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Nombre maximum d'instances"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Nombre d'instances voulu"
  type        = number
  default     = 2
}

# La variable du secret (db_password, ephemeral, sans valeur par defaut) est dans secrets.tf.
