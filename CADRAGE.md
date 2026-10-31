# Fiche de cadrage d'équipe (séance 8)

Terraform et automatisation du déploiement d'infrastructures dans le cloud, Master SRC.
Intervenant : Hemerson KOFFI.

**Équipe :** NovaSphere  **Classe :** Master SRC

| Membre | Rôle | Compte AWS de démonstration |
|---|---|---|
| Pengchao Wang (@Pengchao020401) | P1 Infrastructure et module, référent AWS (bucket du state) | 690898574421 (compte de démo) |
| Bristhis Debgeko (@Bristhis25) | P2 Sécurité (secret SSM, scans, SECURITE.md) | 193179278295 |
| Serdy Adam Siassia Dekamo (@adamdekamo-lgtm) | P3 Automatisation, CI et Git, référent Git | 382361561653 |

La démonstration se fait dans le Learner Lab de Pengchao, qui héberge le bucket du state `novasphere-tfstate-pwa` (us-east-1). Les deux autres comptes y ont accès par la policy du bucket.

## Le contexte

- **Application :** NovaSphere, une plateforme web.
- **Ce que servent les instances :** une page web nginx (« NovaSphere - <environnement> » et le nom du serveur), derrière un Application Load Balancer.
- **Infrastructure :** VPC sur 2 zones de disponibilité, ALB, Auto Scaling Group (2 instances minimum), secret applicatif dans SSM Parameter Store (SecureString écrit en `value_wo`).
- **Environnements :** `dev` et `prod`, dans des dossiers séparés (`envs/dev`, `envs/prod`) avec chacun son state.
- **Déploiement :** GitHub Actions. Plan en commentaire de PR, apply dev au merge, prod après approbation, détection de dérive.

## L'extension choisie (une seule)

- [ ] HTTPS (ACM, listener 443)
- [x] **Administration sans SSH (Session Manager)**
- [ ] Base de données (RDS)
- [ ] Image préconstruite (Packer)
- [ ] Configuration par Ansible
- [ ] Second service derrière l'ALB
- [ ] Tests de module (`terraform test`)

**Ce qu'elle exige en plus du socle :**
- **Ressources :** aucune nouvelle ressource payante. Les instances ont déjà le `LabInstanceProfile` et sortent en HTTPS (port 443) par l'Internet Gateway, donc pas de VPC endpoint ni de NAT. Il faut installer l'agent SSM au démarrage dans `bootstrap.sh` (l'AMI Debian ne l'a pas par défaut) et vérifier que les instances apparaissent dans Systems Manager (Fleet Manager).
- **Coût horaire :** 0 € de plus (Session Manager est gratuit, aucune ressource ajoutée).
- **Temps estimé :** environ 2 heures (modification du script de démarrage, test dans le Lab, documentation dans `SECURITE.md` et `README.md`).
- **Démonstration :** ouvrir un shell sur une instance depuis la console AWS ou `aws ssm start-session --target <instance-id>`, sans port 22 ouvert ni clé SSH.

## Ce que l'équipe écarte, et pourquoi

- **HTTPS (ACM) :** demande un nom de domaine validé, que nous n'avons pas dans le Learner Lab.
- **RDS :** coût horaire élevé pour le budget du Lab, et temps de création long à chaque session.
- **Packer :** ajoute un outil et un pipeline de construction d'image en plus, sans gain visible pour la démonstration.
- **Ansible :** la configuration actuelle tient dans un court `bootstrap.sh`, Ansible serait surdimensionné.
- **Second service derrière l'ALB :** sort du périmètre de l'application (une seule page).
- **Tests de module (`terraform test`) :** gardés comme piste si le temps le permet, mais pas comme extension notée.
- **NAT Gateway :** payante et inutile, les instances sont dans des subnets publics, protégées par leur security group (entrée uniquement depuis l'ALB).

## Validation

Validée par l'intervenant le ________ : [ ] telle quelle [ ] réduite à : ______________________

Signature de l'équipe : ______________________  Signature de l'intervenant : ______________________
