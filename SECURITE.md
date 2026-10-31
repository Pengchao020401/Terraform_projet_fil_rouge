# NovaSphere : sécurité

Partie **P2 : sécurité** du projet. Ce document explique comment les secrets sont gérés, ce qui est protégé, ce qui a été scanné, et surtout **ce qui n'est pas parfait** (section « Risques restants »). Il est écrit pour être relu par le jury.

> **Statut honnête.** Le code du secret est écrit et passe `terraform fmt` et `terraform validate` pour dev et prod. Il a été testé hors ligne (comportement de `value_wo`, validation de la variable). Il n'a **pas encore été déployé** dans le Learner Lab : tout ce qui dépend d'AWS est marqué **« à tester »**. La procédure de test est dans le vault (`Partie securite - comment tester`).

## 1. En résumé

| Sujet | Mesure | État |
|---|---|---|
| Mot de passe applicatif | SSM Parameter Store, type `SecureString`, écrit avec `value_wo` | Écrit et validé, déploiement **à tester** |
| Mot de passe dans le code | Aucune valeur : variable `ephemeral`, sans valeur par défaut | Vérifié par `git grep` |
| Mot de passe dans le state | Absent grâce à `value_wo` (attribut en écriture seule) | Vérifié hors ligne ; sur le vrai state **à tester** |
| Mot de passe dans `user_data` | Absent : le script lit SSM au démarrage | Vérifié (lecture du script) |
| Accès SSH | Aucun (pas de port 22, pas de clé) | Fait |
| Trafic vers les serveurs | Uniquement depuis l'ALB (groupe de sécurité) | Fait |
| Métadonnées de l'instance | IMDSv2 obligatoire, disque racine chiffré | Fait |
| State Terraform | S3 versionné, chiffré, accès public bloqué, verrou `use_lockfile` | Fait |
| Droits IAM des serveurs | `LabInstanceProfile` (limite du Lab), politique idéale documentée | Limite assumée |
| Scans | checkov et trivy, 0 échec restant, exceptions justifiées | Fait |
| Secrets en CI | Secrets GitHub | **À venir** (P3) |

## 2. Gestion du secret

### Le principe
Le mot de passe applicatif est stocké dans **SSM Parameter Store** sous le nom `/novasphere/<env>/db_password` (donc `/novasphere/dev/db_password` et `/novasphere/prod/db_password`). Il est de type `SecureString` : chiffré au repos avec la clé gérée par AWS `aws/ssm`.

Le code est dans `envs/dev/secrets.tf` et `envs/prod/secrets.tf` (identiques, seul le nom d'environnement change) :

```hcl
variable "db_password" {
  type      = string
  sensitive = true
  ephemeral = true   # jamais enregistrée dans le state ni dans le plan
  # pas de "default" : sans TF_VAR_db_password, Terraform refuse de continuer
}

resource "aws_ssm_parameter" "db_password" {
  name             = "/novasphere/${var.environment}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password          # écriture seule
  value_wo_version = var.db_password_version  # pour déclencher une rotation
  tags             = local.tags
}
```

La variable est validée (12 caractères minimum). Cette validation a été testée hors ligne : un mot de passe trop court est refusé avant toute création.

### Pourquoi le mot de passe n'est pas dans le state
- Avec l'attribut classique `value`, Terraform enregistrerait le mot de passe **en clair dans le state** (même avec `sensitive = true`, qui ne cache la valeur qu'à l'affichage).
- `value_wo` est un attribut **en écriture seule** (Terraform 1.11 et plus, provider AWS récent) : Terraform l'envoie à AWS puis l'oublie. Il n'est ni dans le state, ni dans le fichier de plan.
- La variable est `ephemeral = true` : elle n'existe que pendant l'exécution. Elle peut être passée à un attribut en écriture seule, mais pas à un attribut classique (Terraform refuserait de la mettre dans le state). C'est un garde-fou : on ne peut pas écrire `value = var.db_password` par erreur.
- Versions du projet : Terraform `>= 1.14`, provider AWS `~> 6.28` (verrouillé en 6.71.0). Les deux gèrent `value_wo`.

**Test fait hors ligne** (sans AWS, avec un mot de passe jetable) : le plan affiche `value_wo = (write-only attribute)`, et le fichier de plan (binaire et JSON) contient **0 occurrence** du mot de passe. **À refaire sur le vrai state** après un `apply` (voir section 8).

### Conséquence à connaître
Comme Terraform ne garde pas la valeur, il **ne peut pas détecter** qu'elle a changé. Pour faire tourner le mot de passe, on change la valeur **et** on augmente `db_password_version` (par exemple de 1 à 2) : c'est ce numéro, enregistré dans le state, qui déclenche la mise à jour. De plus, `TF_VAR_db_password` doit être fournie à chaque `plan` et `apply`.

### Fournir le mot de passe
- **En local** : saisie masquée, rien dans l'historique du shell ni dans un fichier.

```bash
read -rs TF_VAR_db_password && export TF_VAR_db_password
```

- **En CI** (P3, **à venir**) : un secret GitHub `DB_PASSWORD`, exposé au job sous le nom `TF_VAR_db_password`. Les logs GitHub masquent les secrets, mais on ne doit jamais faire `echo` du mot de passe.
- **Jamais** dans `terraform.tfvars` (ignoré par Git de toute façon) : le fichier `terraform.tfvars.example` ne contient qu'un commentaire.

### Rotation
1. Choisir un nouveau mot de passe et l'exporter dans `TF_VAR_db_password`.
2. Passer `db_password_version` à la valeur suivante (dans `terraform.tfvars`).
3. `terraform apply` : le paramètre SSM reçoit une nouvelle version.
4. Les serveurs lisent le secret **au démarrage seulement** : il faut les renouveler (par exemple un `instance refresh` de l'ASG) pour qu'ils prennent le nouveau mot de passe. Ce renouvellement n'est pas automatisé : **à tester**.

## 3. Comment les serveurs lisent le secret

1. Le Launch Template attache l'instance profile `LabInstanceProfile` : l'instance reçoit des identifiants **temporaires** du rôle `LabRole`, via le service de métadonnées. Aucune clé d'accès n'est écrite sur le serveur.
2. IMDSv2 est **obligatoire** (`http_tokens = required`, limite de 1 saut) : une requête de métadonnées exige un jeton, ce qui bloque les attaques de type SSRF simples. La limite de 1 saut empêche la réponse de quitter l'instance.
3. Au démarrage, `bootstrap.sh` (qui ne contient **aucune valeur sensible**) exécute :

```bash
aws ssm get-parameter --region ${region} --name /novasphere/${environment}/db_password \
  --with-decryption --query Parameter.Value --output text > /etc/novasphere/app.conf
chmod 0640 /etc/novasphere/app.conf
```

4. Dans `web.tf`, le module dépend du paramètre (`depends_on = [aws_ssm_parameter.db_password]`) : les serveurs ne démarrent qu'**après** la création du secret. Sans cela, le script pourrait s'exécuter avant et lire un paramètre inexistant.
5. Le nom du paramètre dans le script (`/novasphere/${environment}/db_password`) est le même que dans `secrets.tf`. Le disque racine est chiffré.

**À tester** : que `LabRole` ait bien le droit de lire un paramètre `SecureString` et de le déchiffrer avec `aws/ssm` dans le Lab. Si ce n'était pas le cas, `app.conf` resterait vide : le site (nginx) fonctionnerait quand même, car le script n'arrête pas nginx.

## 4. IAM : la limite du Learner Lab

Le Learner Lab **interdit de créer un rôle ou une politique IAM**. Les serveurs utilisent donc le profil existant `LabInstanceProfile` (rôle `LabRole`). Ce rôle est **beaucoup plus large que nécessaire** : toute instance dev ou prod pourrait lire n'importe quel paramètre du compte, y compris celui de l'autre environnement. On n'a pas créé de rôle (ce serait refusé) : on documente ce qu'on ferait avec un compte normal.

### Politique idéale (moindre privilège)
Une instance **dev** ne doit pouvoir que lire **son** paramètre, rien d'autre :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOwnSecret",
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:us-east-1:<ID_COMPTE>:parameter/novasphere/dev/db_password"
    },
    {
      "Sid": "DecryptWithAwsSsmKey",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:us-east-1:<ID_COMPTE>:key/<ID_DE_LA_CLE_ALIAS_aws/ssm>",
      "Condition": {
        "StringEquals": { "kms:ViaService": "ssm.us-east-1.amazonaws.com" }
      }
    }
  ]
}
```

- Pas de `Resource = "*"` : le dev ne lit pas le secret de prod (et inversement : une seconde politique pour prod avec `/novasphere/prod/db_password`).
- `kms:Decrypt` est limité à la clé `aws/ssm` et à l'usage via SSM. Avec cette clé gérée par AWS, la politique de la clé autorise déjà l'usage via SSM dans le compte : cette ligne devient indispensable si on passe à une clé CMK. **À vérifier** dans un compte normal.
- Il faut aussi la relation d'approbation (`ec2.amazonaws.com` peut assumer le rôle) et un `aws_iam_instance_profile`. Hors Lab, le code serait un `aws_iam_role`, un `aws_iam_role_policy` et un `aws_iam_instance_profile`, puis `instance_profile_name` pointerait vers ce profil au lieu de `"LabInstanceProfile"`.

## 5. Sécurité réseau

| Flux | Autorisé | Pourquoi |
|---|---|---|
| Internet vers l'ALB | Port 80 (TCP) | Le site doit être joignable (HTTP seulement, voir risques) |
| ALB vers les serveurs | Port 80, **source = groupe de sécurité de l'ALB** | Les serveurs n'acceptent rien d'autre |
| Internet vers les serveurs | **Rien** | Les serveurs ont une IP publique (pas de NAT), mais aucune règle d'entrée ne l'utilise |
| SSH (port 22) | **Aucune règle**, aucune clé SSH | Pas d'administration à distance : on remplace un serveur au lieu de s'y connecter |
| Serveurs vers Internet | Ports 80 et 443 seulement | Installer nginx et awscli, joindre l'API SSM |
| Groupe de sécurité par défaut du VPC | Géré par Terraform et **vidé** (aucune règle) | Personne ne doit l'utiliser par erreur |

Les serveurs ont une IP publique parce que le Lab n'a pas de NAT Gateway (facturée à l'heure). C'est pourquoi `CKV_AWS_130` est ignoré : l'IP publique est utile pour sortir, mais ne permet **aucune entrée**.

## 6. Sécurité du state

Le state est dans le bucket S3 `novasphere-tfstate-pwa`, créé par `bootstrap-state/create-state-bucket.sh` :

- **versioning** activé : on peut revenir à un state précédent ;
- **chiffrement** au repos (SSE-S3) et `encrypt = true` côté Terraform ;
- **blocage de tout accès public** (4 options) ;
- **verrou natif** `use_lockfile = true` (pas de table DynamoDB, qui est dépréciée) ;
- une clé par environnement (`novasphere/dev/...` et `novasphere/prod/...`) ;
- la bucket policy interdit le trafic non chiffré (`aws:SecureTransport`).

**Bucket policy pour les coéquipiers : à venir.** Elle est prête (`bucket-policy.json.template`) mais attend les numéros de compte AWS des coéquipiers, qui donneront l'accès à leur `LabRole` (`arn:aws:iam::<compte>:role/LabRole`). Tant qu'elle n'est pas appliquée, seul le propriétaire du bucket accède au state. Les `LabRole` ont besoin de `GetObject`, `PutObject` et `DeleteObject` (le verrou crée et supprime un fichier `.tflock`).

Même avec `value_wo`, le state contient d'autres informations sensibles (identifiants de ressources, adresses IP). Il ne doit **jamais** être commité (`.gitignore`) ni partagé hors du bucket.

## 7. Résultats des scans

Détail complet dans le vault (`Checkov - resultats projet`). Scans faits sans AWS, avec checkov 3.3.30 et trivy 0.76.1.

| Outil | Cible | Réussis | Échecs | Ignorés |
|---|---|---|---|---|
| checkov | module `terraform-aws-web` | 39 | 0 | 9 |
| checkov | `envs/dev` (modules téléchargés) | 115 | 0 | 20 |
| checkov | `envs/prod` (modules téléchargés) | 115 | 0 | 20 |
| checkov | `bootstrap-state` | 0 | 0 | 0 (scripts shell, pas de Terraform) |
| trivy config | `envs/dev`, `envs/prod`, module | 70 chacun | 0 | 4 règles dans `.trivyignore` |
| trivy secret | tout le projet | n/a | 0 secret trouvé | n/a |

**Ce qui a été corrigé** : le groupe de sécurité par défaut du VPC est maintenant géré et vidé. Un premier scan sans téléchargement des modules cachait 2 échecs (`CKV_AWS_130` et `CKV2_AWS_12`) ; il faut scanner avec `--download-external-modules true`.

**Ce qui est justifié, pas corrigé** (chaque exception est écrite dans le code avec `#checkov:skip=ID:raison`, ou dans `.trivyignore`) :

| Règle | Raison |
|---|---|
| `CKV_AWS_2`, `CKV_AWS_103`, `CKV2_AWS_20`, `AWS-0054` (HTTP) | Pas de HTTPS : il faudrait un certificat et un nom de domaine, impossible simplement dans le Lab |
| `CKV_AWS_260` (x2) | Port 80 public voulu sur l'ALB ; faux positif sur la règle ALB vers serveurs (source = groupe de sécurité) |
| `CKV_AWS_91`, `CKV_AWS_150` | Pas de logs d'accès (bucket en plus) ni de protection contre la suppression (`destroy` obligatoire) |
| `CKV2_AWS_28` | Pas de WAF : coût, hors périmètre |
| `CKV_AWS_378` | HTTP entre l'ALB et les serveurs, à l'intérieur du VPC |
| `CKV_AWS_130`, `AWS-0164` | IP publique voulue (pas de NAT) |
| `CKV2_AWS_12` | Faux positif (groupe par défaut géré et vidé) |
| `CKV_TF_1` (x2) | Modules épinglés par version / tag, pas par hash de commit |
| `CKV_AWS_337` | Clé `aws/ssm` gérée par AWS au lieu d'une CMK : coût et droits KMS non garantis dans le Lab |
| `AWS-0104` | Sortie des serveurs limitée aux ports 80 et 443 (pas fermée : nécessaire pour installer nginx) |
| `AWS-0178` | Pas de logs de flux du VPC : coût, hors périmètre |

Les alertes les plus sérieuses de trivy (listener HTTP, sortie vers Internet) viennent du **module figé en `v1.0.0`** : on les documente, on ne modifie pas un tag publié.

Commandes :

```bash
checkov -d envs/dev --download-external-modules true
trivy config --ignorefile .trivyignore envs/dev
trivy fs --scanners secret .
```

## 8. Vérifier qu'aucun secret n'a fuité

À lancer à la racine du dépôt avant chaque push (aucune commande ne doit afficher de valeur) :

```bash
git ls-files | grep -E '\.tfstate|\.tfvars$|\.pem$|^\.env$|\.terraform/' || echo "OK : aucun fichier sensible suivi par Git"
git grep -nE 'AKIA[0-9A-Z]{16}|aws_secret_access_key|aws_session_token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- . ':!README.md' ':!ARCHITECTURE.md' ':!SECURITE.md' || echo "OK : aucun identifiant AWS trouvé"
git grep -niE 'password *= *"' -- '*.tf' || echo "OK : aucun mot de passe en clair dans les .tf"
```

Pour l'historique Git, un outil de type gitleaks fait la même chose sur tous les commits (**à tester**, non installé ici) :

```bash
gitleaks detect --source . --redact
```

**Preuve pour le state** (après un `apply` réel, **à tester**). Remplacer la valeur par le mot de passe saisi, sans l'écrire dans l'historique :

```bash
terraform state pull | grep -c "$TF_VAR_db_password"
```

Le résultat attendu est `0`. De même pour le plan : `terraform show -json tfplan | grep -c "$TF_VAR_db_password"` doit donner `0`.

Vérifier que le paramètre existe, **sans afficher sa valeur** :

```bash
aws ssm get-parameter --name /novasphere/dev/db_password --query 'Parameter.[Name,Type,Version]' --output text
```

## 9. Secrets en CI (P3, à venir)
- Identifiants AWS de session du Lab et `DB_PASSWORD` dans les **secrets du dépôt GitHub** (jamais dans le code ni dans un fichier de workflow).
- Le job exporte `TF_VAR_db_password` à partir du secret et n'affiche jamais sa valeur.
- Le fichier de plan produit par la CI ne contient pas le mot de passe (variable `ephemeral`) : c'est vérifié hors ligne, mais **à tester** en vrai.
- Prod derrière un environnement GitHub protégé (approbation manuelle). Avec un compte AWS personnel, on utiliserait OIDC plutôt que des clés.

## 10. Risques restants

1. **`LabInstanceProfile` trop large** : une instance dev peut lire le secret de prod. Limite du Lab, politique idéale en section 4.
2. **Le mot de passe est écrit en clair sur le disque du serveur** (`/etc/novasphere/app.conf`, droits 0640, disque chiffré). Il est lisible par root et par le groupe du fichier. Le fichier est créé avant le `chmod` : une fenêtre très courte où il est lisible avec les droits par défaut. Améliorer : `umask 077` dans le script, ou une application qui lit SSM directement.
3. **Pas de HTTPS** : le trafic entre le navigateur et l'ALB est en clair. Aucun secret n'y passe, mais ce n'est pas acceptable en production réelle.
4. **Pas de chiffrement par clé CMK**, ni de journal d'audit (CloudTrail) des lectures du secret, ni de logs d'accès de l'ALB.
5. **Mot de passe simple à valider** : seule la longueur est vérifiée (12 caractères), pas la complexité.
6. **Rotation manuelle** : il faut augmenter `db_password_version` et renouveler les serveurs.
7. **Un mot de passe par environnement** : si dev et prod utilisent la même valeur, la séparation des deux environnements ne sert à rien. Il faut deux valeurs différentes.
8. **Bucket policy des coéquipiers pas encore appliquée** (en attente de leurs numéros de compte).
9. **Rien de tout cela n'est encore déployé en vrai** : voir la liste « à tester » ci-dessous.

## 11. À tester dans le Learner Lab
- `apply` de dev avec `TF_VAR_db_password` : le paramètre est créé, les serveurs deviennent sains.
- `LabRole` lit et déchiffre le `SecureString` (le fichier `app.conf` n'est pas vide : à vérifier par une session sur l'instance si possible, sinon via les journaux de démarrage `cloud-init`).
- `terraform state pull | grep` du mot de passe : 0 résultat.
- `plan` après l'`apply` : « No changes » (le groupe par défaut vidé ne doit plus bouger).
- Rotation avec `db_password_version = 2`.
