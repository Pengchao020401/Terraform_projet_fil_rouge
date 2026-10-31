#!/usr/bin/env bash
# Cree UNE FOIS le bucket S3 du state partage (a lancer par le referent AWS, dans son Learner Lab).
# Usage : ./create-state-bucket.sh <trigramme> [arn_labrole_coequipier ...]
# Exemple : ./create-state-bucket.sh pwa arn:aws:iam::111111111111:role/LabRole arn:aws:iam::222222222222:role/LabRole
set -euo pipefail

TRI="${1:?Usage: $0 <trigramme> [arn_labrole ...]}"
shift || true
REGION="us-east-1"
BUCKET="novasphere-tfstate-${TRI}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "Compte AWS utilise :"
aws sts get-caller-identity --query Account --output text

# 1. Bucket (us-east-1 : pas de LocationConstraint)
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"

# 2. Versioning : permet de revenir a un state precedent
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# 3. Chiffrement au repos
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# 4. Aucun acces public
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 5. Policy pour les LabRole des coequipiers (si des ARN sont donnes)
if [ "$#" -gt 0 ]; then
  PRINCIPALS=$(printf '"%s",' "$@")
  PRINCIPALS="[${PRINCIPALS%,}]"
  sed -e "s|__BUCKET__|${BUCKET}|g" -e "s|\"__PRINCIPALS__\"|${PRINCIPALS}|" \
    "$HERE/bucket-policy.json.template" > "$HERE/bucket-policy.generated.json"
  aws s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$HERE/bucket-policy.generated.json"
  echo "Policy appliquee pour : $*"
fi

echo "Bucket pret : $BUCKET"
echo "A reporter dans envs/dev/backend.tf et envs/prod/backend.tf (champ bucket)."
