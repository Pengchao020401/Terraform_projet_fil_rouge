# NovaSphere : infrastructure Terraform sur AWS

Projet fil rouge du Master SRC (encadrant : Hemerson KOFFI).
Ce dépôt déploie une infrastructure web en haute disponibilité sur **AWS Academy Learner Lab** (région `us-east-1`) : un Application Load Balancer devant un groupe d'auto-scaling d'au moins 2 serveurs nginx, répartis sur 2 zones de disponibilité. Il y a deux environnements isolés, **dev** et **prod**.

> État d'avancement : dev et prod sont déployés par la CI GitHub Actions (prod après approbation) et testés de bout en bout. Le secret SSM, la bucket policy pour les coéquipiers et l'extension Session Manager sont en place (voir la section « Avancement » et `RESTE_A_FAIRE.md`).

## Documentation

| Document | Contenu | Responsable |
|---|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Schéma, composants, choix de conception et alternatives | P1 |
| [SECURITE.md](SECURITE.md) | Secrets, politique IAM idéale, réseau, résultats des scans, vérifications anti-secret | P2 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Règles de travail en équipe | P3 |
| [CADRAGE.md](CADRAGE.md) | Fiche de cadrage : équipe, extension choisie (Session Manager), options écartées | Équipe |
| [RESTE_A_FAIRE.md](RESTE_A_FAIRE.md) | État final du projet, ce qui reste à faire, limites connues | Équipe |

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
├── SECURITE.md                secrets, politique IAM idéale, résultats des scans
├── CONTRIBUTING.md            règles de travail en équipe
├── CADRAGE.md                 fiche de cadrage et extension choisie
├── RESTE_A_FAIRE.md           état final, reste à faire, limites connues
├── .github/workflows/         CI/CD GitHub Actions (ci-cd.yml)
├── .gitignore                 exclut state, tfvars, clés, cache Terraform
├── .gitattributes             fins de ligne Linux (LF) pour .sh, .tf, .hcl, .md...
├── .trivyignore               exceptions du scan trivy, avec leur justification
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
    │   ├── secrets.tf         secret SSM (SecureString, value_wo) et sa variable ephemeral
    │   ├── bootstrap.sh       script de démarrage des serveurs (nginx, agent SSM, lecture du secret)
    │   └── outputs.tf         URL de l'ALB, nom de l'ASG...
    └── prod/                  mêmes fichiers ; seuls backend.tf et les valeurs changent
```

## Module d'équipe

Le module `terraform-aws-web` (ALB, target group, Launch Template, ASG, groupes de sécurité) est dans son **propre dépôt** :
[Pengchao020401/terraform-aws-web](https://github.com/Pengchao020401/terraform-aws-web). Il est appelé par tag, jamais par branche :

```hcl
source = "git::https://github.com/Pengchao020401/terraform-aws-web.git?ref=v1.0.1"
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

Fournir le mot de passe applicatif **par l'environnement**, jamais dans un fichier (saisie masquée, 12 caractères minimum) :

```bash
read -rs TF_VAR_db_password && export TF_VAR_db_password
```

Il est stocké dans SSM Parameter Store (voir [SECURITE.md](SECURITE.md)). Ensuite :

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

La variable `db_password` est *ephemeral* : elle n'est pas enregistrée dans le fichier de plan. `TF_VAR_db_password` doit donc rester exportée pour l'`apply` (et pour tout `plan` ultérieur).

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

## Extension : administration sans SSH (Session Manager)

Les serveurs n'ont ni port 22 ni clé SSH. On s'y connecte par **SSM Session Manager** : l'agent SSM est installé par `bootstrap.sh` et l'instance s'enregistre grâce au `LabInstanceProfile`. Cette extension a été testée dans le Learner Lab : les serveurs apparaissent `Online` dans Systems Manager et un terminal s'ouvre depuis la console. Le choix est expliqué dans [CADRAGE.md](CADRAGE.md).

**Par la console AWS** : EC2, puis Instances, cocher un serveur `novasphere-<env>`, cliquer sur **Connect**, choisir l'onglet **SSM Session Manager**, puis **Connect**. Un terminal s'ouvre dans le navigateur.

**Par la ligne de commande** (demande le plugin Session Manager pour AWS CLI) :

```bash
aws ssm describe-instance-information --query "InstanceInformationList[].[InstanceId,PingStatus]" --output table
aws ssm start-session --target <instance-id>
```

La première commande liste les serveurs joignables (`Online`). Si la liste est vide juste après un déploiement, attendre 2 minutes : l'agent démarre à la fin de l'installation.

## Intégration continue (CI)

La CI utilise GitHub Actions (`.github/workflows/ci-cd.yml`, responsable P3) :

- sur chaque Pull Request : `terraform fmt -check`, checkov, `init`, `validate`, puis le plan de dev en commentaire ;
- au merge sur `main` : `apply` de dev, puis `apply` de prod **après approbation manuelle** (environnement GitHub `prod`) ;
- les fichiers `.md` sont ignorés (`paths-ignore`) : une modification de documentation ne déclenche pas de déploiement ;
- un job de détection de dérive (`plan -detailed-exitcode`), lancé chaque matin de semaine et à la demande.

La CI fournit les variables `TF_VAR_owner`, `TF_VAR_environment`, `TF_VAR_vpc_cidr` et `TF_VAR_db_password` (secret GitHub `DB_PASSWORD`). Dans le Learner Lab, elle utilise les identifiants de session stockés dans les secrets du dépôt : **ils expirent à chaque session** et sont à rafraîchir avant la démonstration. Avec un compte AWS personnel, on utiliserait un rôle OIDC, impossible à créer dans le Lab.

## Sécurité

- **Aucun secret dans le dépôt, le state ni le script de démarrage.** Le mot de passe applicatif est dans SSM Parameter Store (SecureString), écrit avec `value_wo` à partir d'une variable *ephemeral* (`TF_VAR_db_password`), et lu par les serveurs au démarrage. Déployé en dev et en prod par la CI ; le mot de passe n'apparaît pas dans le state (vérifié).
- Les serveurs n'ont **pas de SSH** (administration par Session Manager, voir plus haut) et n'acceptent le trafic que de l'ALB.
- IMDSv2 est obligatoire et le disque racine est chiffré.
- Scans : checkov sur `envs/dev` et `envs/prod` (modules compris) : 115 contrôles réussis, 0 échec, 20 ignorés par environnement (résultat confirmé le 31/10/2026 avec checkov 3.4.0), chaque exception justifiée dans le code ; trivy : 0 alerte restante, 4 exceptions justifiées dans `.trivyignore`. Détail dans [SECURITE.md](SECURITE.md).
- Le state et les fichiers `*.tfvars` sont exclus par `.gitignore`.

### Vérifier qu'aucun secret n'est commité

À lancer à la racine du dépôt avant chaque push :

```bash
git ls-files | grep -E '\.tfstate|\.tfvars$|\.pem$|^\.env$|\.terraform/' || echo "OK : aucun fichier sensible suivi par Git"
git grep -nE 'AKIA[0-9A-Z]{16}|aws_secret_access_key|aws_session_token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- . ':!README.md' ':!ARCHITECTURE.md' ':!SECURITE.md' || echo "OK : aucun identifiant AWS trouvé"
git grep -niE 'password *= *"' -- '*.tf' || echo "OK : aucun mot de passe en clair dans les .tf"
```

Chaque commande doit afficher « OK ». Le fichier `terraform.tfvars.example` est le seul `*.tfvars*` autorisé, et il ne contient aucune valeur sensible.

## Avancement

| Élément | État |
|---|---|
| State S3 partagé (versionné, chiffré, verrou natif) | Fait |
| Module `terraform-aws-web` v1.0.1 | Fait |
| `envs/dev` | Déployé et testé dans le Learner Lab |
| `envs/prod` | Déployé par la CI après approbation et testé dans le Learner Lab |
| Bucket policy pour les coéquipiers | Appliquée (comptes de P2 et P3) |
| Secret SSM (`value_wo`) | Déployé en dev et en prod, absent du state (vérifié) |
| `SECURITE.md`, scans checkov et trivy | Fait (les points restant à vérifier y sont indiqués) |
| CI GitHub Actions, `CONTRIBUTING.md` | Fait : dev et prod déployés par la CI, prod derrière approbation |
| Extension : administration sans SSH (Session Manager) | Faite et testée (voir `CADRAGE.md`) |
| `CADRAGE.md`, `RESTE_A_FAIRE.md` | Fait |

## Équipe

| Rôle | Membre | Responsabilités |
|---|---|---|
| P1 : infrastructure, référent AWS | Pengchao WANG ([@Pengchao020401](https://github.com/Pengchao020401)) | State S3, `envs/dev` et `envs/prod`, module `terraform-aws-web`, `ARCHITECTURE.md`, tag `rendu-final` (posé par Pengchao) |
| P2 : sécurité | Bristhis Debgeko (@Bristhis25) | Secret SSM, politique IAM idéale, scan checkov, `SECURITE.md` |
| P3 : automatisation, référent Git | Serdy Adam Siassia Dekamo (@adamdekamo-lgtm) | GitHub Actions, protection de `main`, `CONTRIBUTING.md` |

Règles d'équipe : chacun commite depuis son poste sous son propre nom, chaque Pull Request est relue par un autre membre, aucun push direct sur `main`.
