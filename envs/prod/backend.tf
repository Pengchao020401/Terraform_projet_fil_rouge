# State partage dans S3 : un fichier par environnement (cle differente), verrou natif par fichier .tflock.
# Le bucket est cree une fois a la main par le referent AWS : voir ../../bootstrap-state/.
# Pas de dynamodb_table (deprecie) : use_lockfile = true.
terraform {
  backend "s3" {
    bucket       = "novasphere-tfstate-pwa" # a remplacer par le nom du bucket cree
    key          = "novasphere/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
