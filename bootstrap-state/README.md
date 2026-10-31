# bootstrap-state : creer le bucket du state partage

Le state Terraform est stocke dans un bucket S3 pour que toute l'equipe travaille sur le meme etat.
Ce bucket ne peut pas etre cree par Terraform lui-meme (il faut qu'il existe avant le premier `init`),
donc on le cree **une seule fois, a la main**, avec le script de ce dossier.

## Qui le lance ?
Un seul membre, le referent AWS (ici P1). Le bucket vit dans son compte Learner Lab.

## Etapes
1. Demarrer le Learner Lab et exporter les identifiants (voir `Notions/Learner Lab` dans le vault).
2. Recuperer l'ARN du `LabRole` de chaque coequipier : chacun lance `aws sts get-caller-identity`
   et donne le champ `Account`. L'ARN est `arn:aws:iam::<ACCOUNT>:role/LabRole`.
3. Lancer : `./create-state-bucket.sh <trigramme> <arn_labrole_1> <arn_labrole_2> ...`
4. Reporter le nom du bucket dans `envs/dev/backend.tf` et `envs/prod/backend.tf`.
5. Chaque coequipier fait `terraform init` dans son env : si l'acces est refuse, la policy est a corriger.

## Points a tester (non verifies ici : pas d'AWS sur la machine qui a genere ce code)
- L'acces entre comptes avec `LabRole` doit etre teste : la policy du bucket autorise le role, mais le role
  du lab doit aussi avoir le droit d'appeler S3 (c'est en general le cas).
- Les identifiants du lab changent a chaque session ; le **bucket**, lui, peut disparaitre quand le lab est reinitialise.
  Sauvegarder le state (`terraform state pull > state.json`) avant la fin d'une session importante.
- Le verrou `use_lockfile` cree un fichier `.tflock` a cote du state : il faut donc aussi `PutObject` et `DeleteObject`.
