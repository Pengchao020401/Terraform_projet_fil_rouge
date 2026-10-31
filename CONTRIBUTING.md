# Contribuer au projet NovaSphere

Règles d'équipe (reprises de la séance 1, adaptées au projet).

## Équipe

| Rôle | Membre | GitHub |
|---|---|---|
| P1 Infrastructure et module | Pengchao Wang | @Pengchao020401 |
| P2 Sécurité | Bristhis Debgeko | @Bristhis25 |
| P3 Automatisation, CI et Git | Serdy Adam Siassia Dekamo | @adamdekamo-lgtm |

## Branches

- `main` est la branche de référence : **personne ne pousse directement dessus**.
- Une branche par tâche, partie de `main` à jour :
  - `feat/<sujet>` pour une nouveauté (ex. `feat/securite`)
  - `fix/<sujet>` pour une correction (ex. `fix/workflow-ci`)
  - `docs/<sujet>` pour la documentation
- Une branche est supprimée après son merge.

```bash
git checkout main
git pull
git checkout -b feat/mon-sujet
```

## Commits

- Chacun commite **depuis son poste, sous son propre nom**.
- Messages courts au format `type(portée): description` :
  `feat(web): ajoute le health check ELB`, `fix(ci): region us-east-1`, `docs: README`.
- Petits commits, un sujet par commit.

## Pull requests

1. Pousser la branche puis ouvrir une PR vers `main` :
   ```bash
   git push -u origin feat/mon-sujet
   gh pr create --base main --fill
   ```
2. La CI lance `fmt`, `validate`, checkov et `terraform plan` (dev), puis publie le plan en commentaire.
3. Un **autre membre** relit le code et le plan avant le merge.
4. Merge quand la CI est verte : `gh pr merge --merge --delete-branch`.
5. Le merge sur `main` déclenche l'apply en dev ; la prod demande une approbation manuelle.

## Avant de pousser

```bash
terraform fmt -recursive
terraform -chdir=envs/dev validate
checkov -d envs/dev
```

## Interdits (vérifiés à chaque PR)

- Aucun secret dans Git : pas de `terraform.tfstate`, `terraform.tfvars`, clé AWS, mot de passe ni `.terraform/`.
- Pas de valeur par défaut pour `db_password` ; le mot de passe passe par `TF_VAR_db_password`, généré en local.
- Pas de bloc `provider` dans le module `terraform-aws-web`.
- Pas de modification manuelle des ressources dans la console AWS (elle serait détectée comme dérive).

## Module d'équipe

- Le module vit dans [terraform-aws-web](https://github.com/Pengchao020401/terraform-aws-web) et est consommé **par tag** (`?ref=v1.0.1`).
- Toute modification du module donne un **nouveau tag** (`v1.0.2`, `v1.1.0`…) ; un tag publié n'est jamais déplacé.
- Puis une PR dans ce dépôt met à jour le `ref=` de `envs/dev/web.tf` et `envs/prod/web.tf`.

## Learner Lab

- Les credentials de session vont dans `~/.aws/credentials` (en local) et dans les secrets GitHub (CI), **jamais** dans un fichier versionné ni dans un message.
- Toujours lancer `terraform destroy` en fin de session.
