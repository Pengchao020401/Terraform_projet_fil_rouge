# NovaSphere : infrastructure Terraform sur AWS

Projet fil rouge du Master SRC (encadrant : Hemerson KOFFI).
Ce dépôt déploie une infrastructure web en haute disponibilité sur **AWS Academy Learner Lab** (région `us-east-1`) : un Application Load Balancer devant un groupe d'auto-scaling d'au moins 2 serveurs nginx, répartis sur 2 zones de disponibilité. Il y a deux environnements isolés, **dev** et **prod**.

> État d'avancement : dev est déployé et testé. Prod, le secret SSM, la bucket policy pour les coéquipiers et la CI GitHub Actions sont **à venir** (voir la section « Avancement »).

## Documentation

| Document | Contenu | Responsable |
|---|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Schéma, composants, choix de conception et alternatives | P1 |
| SECURITE.md | Secrets, politique IAM idéale, résultats du scan : **à venir** | P2 |
| CONTRIBUTING.md | Règles de travail en équipe : **à venir** | P3 |

## Prérequis

| Outil | Version | Remarque |
|---|---|---|
| Terraform | **1.14 ou plus** (`required_version = ">= 1.14"` dans `versions.tf`) | `use_lockfile` demande au moins 1.10 |
| Provider AWS | `~> 6.28` | Installé par `terraform init`, version figée par `.terraform.lock.hcl` |
| AWS CLI | version 2 | Pour créer le bucket du state et vérifier les identifiants |
| Git | récent | |
| Système | Linux ou WSL (Ubuntu) | Les fichiers `.sh` doivent avoir des fins de ligne Linux (`.gitattributes` s'en occupe) |
| Accès | Un **AWS Academy Learner Lab** démarré | Région `us-east-1` |

## Organisation du dépôt

```
Terraform_projet_fil_rouge/
├── README.md                  ce fichier
├── ARCHITECTURE.md            schéma et choix de conception
├── .gitignore                 exclut state, tfvars, clés, cache Terraform
├── .gitattributes             fins de ligne Linux pour .sh, .tf, .hcl
├── bootstrap-state/           création du bucket S3 du state (une seule fois)
│   ├── create-state-bucket.sh
│   ├── bucket-policy.json.template
│   └── README.md
└── envs/
    ├── dev/                   environnement de développement
    │   ├── versions.tf        versions de Terraform et du provider, région
    │   ├── backend.tf         state dans S3 (clé novasphere/dev/...)
    │   ├── variables.tf       variables avec validations
    │   ├── terraform.tfvars.example   exemple de valeurs (à copier)
    │   ├── main.tf            image Debian 12, nom et étiquettes
    │   ├── network.tf         VPC du registre public (2 zones, subnets publics, sans NAT)
    │   ├── web.tf             appel du module d'équipe par tag
    │   ├── bootstrap.sh       script de démarrage des serveurs
    │   └── outputs.tf         URL de l'ALB, nom de l'ASG...
    └── prod/                  mêmes fichiers ; seuls backend.tf et les valeurs changent
```

À venir : `.github/workflows/` (CI, P3), `SECURITE.md` (P2), `CONTRIBUTING.md` et `secrets.tf` (P2).

## Module d'équipe

Le module `terraform-aws-web` (ALB, target group, Launch Template, ASG, groupes de sécurité) est dans son **propre dépôt** :
[Pengchao020401/terraform-aws-web](https://github.com/Pengchao020401/terraform-aws-web). Il est appelé par tag, jamais par branche :

```hcl
source = "git::https://github.com/Pengchao020401/terraform-aws-web.git?ref=v1.0.0"
```

Un tag publié n'est jamais modifié. Pour une évolution : nouveau tag (`v1.1.0`), puis mise à jour de `?ref=` dans `envs/dev/web.tf`, test en dev, puis dans `envs/prod/web.tf`.

## Démarrage rapide

Les commandes se lancent depuis Linux ou WSL.

### 0. Identifiants du Learner Lab

1. Démarrer le Learner Lab et attendre que le voyant soit vert.
2. Ouvrir *AWS Details*, puis *AWS CLI : Show*.
3. Coller les trois valeurs dans le terminal :

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
```

4. Vérifier :

```bash
aws sts get-caller-identity
```

Ces identifiants changent à chaque session. **Ne les écrivez jamais dans un fichier du dépôt.**

### 1. Créer le bucket du state (une seule fois, par le référent AWS : P1)

Ne pas refaire cette étape si le bucket `novasphere-tfstate-pwa` existe déjà.

```bash
cd bootstrap-state
./create-state-bucket.sh pwa
```

Pour donner accès aux coéquipiers, ajouter l'ARN du `LabRole` de chacun (`arn:aws:iam::<compte>:role/LabRole`) à la fin de la commande. Détails dans [bootstrap-state/README.md](bootstrap-state/README.md).
Le nom du bucket doit correspondre au champ `bucket` de `envs/dev/backend.tf` et `envs/prod/backend.tf`.

### 2. Déployer un environnement

Exemple pour **dev** (pour **prod**, remplacer `dev` par `prod`) :

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Ouvrir `terraform.tfvars` et remplacer `owner` par votre trigramme (3 lettres minuscules, par exemple `pwa`). Ce fichier est ignoré par Git : il ne doit jamais être commité.

Ensuite :

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Le premier `apply` attend que les serveurs soient sains dans l'ALB : comptez quelques minutes. Si l'apply s'arrête sur l'erreur du rôle `AWSServiceRoleForAutoScaling`, relancez-le : ce rôle venait d'être créé par AWS.

### 3. Vérifier

```bash
terraform output alb_url
curl "$(terraform output -raw alb_url)"
```

Vous devez voir `NovaSphere - dev` (ou `prod`) et le nom d'un serveur. En relançant la commande, le nom de la machine doit alterner entre 2 serveurs.
Après le déploiement, `terraform plan` doit afficher `No changes`.

### 4. Détruire (obligatoire à la fin de chaque session)

```bash
terraform destroy
```

Les ressources sont facturées à l'heure sur le budget du Learner Lab. Ne détruisez **pas** le bucket du state.

### Valeurs par défaut des environnements

| | dev | prod |
|---|---|---|
| CIDR du VPC | `10.0.0.0/16` | `10.1.0.0/16` |
| Type d'instance | `t3.micro` | `t3.small` |
| Instances min / voulu / max | 2 / 2 / 4 | 2 / 3 / 6 |
| Clé du state | `novasphere/dev/terraform.tfstate` | `novasphere/prod/terraform.tfstate` |

## Intégration continue (CI)

**À venir : responsable P3.** Elle sera faite avec GitHub Actions :

- sur chaque Pull Request : `terraform fmt -check`, `validate`, puis le plan en commentaire ;
- au merge sur `main` : `apply` de dev à partir du fichier de plan ;
- prod : derrière un environnement GitHub protégé (approbation manuelle) ;
- un job de détection de dérive (`plan -detailed-exitcode`).

La CI fournira les variables `TF_VAR_owner`, `TF_VAR_environment` et `TF_VAR_vpc_cidr`. Dans le Learner Lab, elle utilise les identifiants de session stockés dans les secrets du dépôt (à rafraîchir avant la démonstration). Avec un compte AWS personnel, on utiliserait un rôle OIDC.

## Sécurité

- **Aucun secret dans le dépôt.** Le mot de passe applicatif sera dans SSM Parameter Store (SecureString), créé par P2 et lu par les serveurs au démarrage : **à venir**.
- Les serveurs n'ont **pas de SSH** et n'acceptent le trafic que de l'ALB.
- IMDSv2 est obligatoire et le disque racine est chiffré.
- Le module a été scanné avec checkov : 39 contrôles réussis, 0 échec, 9 exceptions justifiées dans le code.
- Le state et les fichiers `*.tfvars` sont exclus par `.gitignore`.

### Vérifier qu'aucun secret n'est commité

À lancer à la racine du dépôt avant chaque push :

```bash
git ls-files | grep -E '\.tfstate|\.tfvars$|\.pem$|^\.env$|\.terraform/' || echo "OK : aucun fichier sensible suivi par Git"
git grep -nE 'AKIA[0-9A-Z]{16}|aws_secret_access_key|aws_session_token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- . ':!README.md' ':!ARCHITECTURE.md' || echo "OK : aucun identifiant AWS trouvé"
git grep -niE 'password *= *"' -- '*.tf' || echo "OK : aucun mot de passe en clair dans les .tf"
```

Chaque commande doit afficher « OK ». Le fichier `terraform.tfvars.example` est le seul `*.tfvars*` autorisé, et il ne contient aucune valeur sensible.

## Avancement

| Élément | État |
|---|---|
| State S3 partagé (versionné, chiffré, verrou natif) | Fait |
| Module `terraform-aws-web` v1.0.0 | Fait |
| `envs/dev` | Déployé et testé dans le Learner Lab |
| `envs/prod` | Écrit, validé, **déploiement à tester** |
| Bucket policy pour les coéquipiers | **À venir** (en attente de leurs numéros de compte) |
| Secret SSM (`value_wo`), `SECURITE.md` | **À venir** (P2) |
| CI GitHub Actions, `CONTRIBUTING.md` | **À venir** (P3) |
| Extension (bonus) | À décider |

## Équipe

| Rôle | Membre | Responsabilités |
|---|---|---|
| P1 : infrastructure, référent AWS | Pengchao WANG ([@Pengchao020401](https://github.com/Pengchao020401)) | State S3, `envs/dev` et `envs/prod`, module `terraform-aws-web`, `ARCHITECTURE.md` |
| P2 : sécurité | à compléter | Secret SSM, politique IAM idéale, scan checkov, `SECURITE.md` |
| P3 : automatisation, référent Git | à compléter | GitHub Actions, protection de `main`, `CONTRIBUTING.md`, tag `rendu-final` |

Règles d'équipe : chacun commite depuis son poste sous son propre nom, chaque Pull Request est relue par un autre membre, aucun push direct sur `main`.
