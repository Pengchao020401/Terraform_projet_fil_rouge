# NovaSphere : reste à faire

Date : 31/10/2026
Équipe : Pengchao Wang, Bristhis Debgeko, Serdy Adam Siassia Dekamo
Encadrant : Hemerson KOFFI

## État du projet

Tout ce qui suit a été testé de bout en bout dans le Learner Lab (us-east-1) :

- **Dev et prod déployés par la CI.** Chaque merge sur `main` lance l'apply de dev, puis attend l'approbation d'un relecteur avant l'apply de prod. Le run du merge de la PR #4 est vert sur les deux environnements. Les 3 serveurs de prod répondent derrière l'ALB.
- **Prod protégée par une approbation.** L'environnement GitHub `prod` demande une validation manuelle. Sur les merges suivants (PR #7, #8, #9), l'apply de dev est passé et la prod a été refusée volontairement pour ne pas payer deux environnements.
- **Extension Session Manager testée.** L'agent SSM est installé par `bootstrap.sh`. Les 2 serveurs de dev sont apparus `Online` dans Systems Manager et on a ouvert un terminal dessus depuis la console AWS, port 22 fermé, sans clé SSH.
- **State partagé avec verrou.** Le state est dans le bucket S3 `novasphere-tfstate-pwa`, avec `use_lockfile = true` et un fichier d'état par environnement.
- **Bucket policy pour les coéquipiers.** Elle est appliquée avec les comptes de Bristhis (193179278295) et de Serdy (382361561653).
- **Secret hors du state.** Le mot de passe est dans SSM Parameter Store (`value_wo` et variable `ephemeral`). Une recherche du mot de passe dans le state a donné 0 résultat.
- **Scans.** `terraform fmt` et `terraform validate` passent sur dev et prod (Terraform 1.14.0). checkov 3.4.0 : 115 contrôles réussis, 0 échec, 20 ignorés avec justification, pour chacun de dev et de prod. Aucun secret, `.tfstate` ni `.tfvars` dans l'historique Git.
- **Équipe et Git.** Travail en Pull Requests uniquement, `main` protégée, `CONTRIBUTING.md` et `CADRAGE.md` écrits.
- **Tout est détruit.** Dev a été détruit (24 ressources) après le dernier test. Le bucket du state est conservé.

## Ce qui reste à faire

Ce sont des pistes que nous n'avons pas faites. Rien ne bloque le rendu.

- **Tests du module (`terraform test`)** : Serdy Adam Siassia Dekamo. Le dépôt `terraform-aws-web` n'a aucun test, seulement `fmt`, `validate` et checkov en CI. Quelques tests sur les variables et les sorties, lancés par la CI, rendraient le module plus sûr à faire évoluer. Effort estimé : 3 heures.
- **Durcir la lecture du secret sur le serveur** : Bristhis Debgeko. Dans `bootstrap.sh`, le fichier `/etc/novasphere/app.conf` est créé avant son `chmod`, donc lisible un très court instant avec les droits par défaut (risque n°2 de `SECURITE.md`). Il faut ajouter `umask 077`, en gardant le script à 10 lignes maximum, tester en dev, puis faire un nouveau tag du dépôt si le module change. On lancerait aussi `gitleaks` sur tout l'historique, prévu mais jamais lancé dans `SECURITE.md`. Effort estimé : 1 heure.
- **HTTPS avec ACM (listener 443)** : Pengchao Wang. Aujourd'hui le trafic navigateur vers l'ALB est en clair (HTTP), ce qui est écarté dans `CADRAGE.md` et documenté dans `SECURITE.md`. Cela demande un nom de domaine validé, que nous n'avons pas dans le Learner Lab. Effort estimé : 4 heures, une fois un domaine disponible.

## Limites connues

- **Les identifiants du Learner Lab expirent à chaque session.** La CI utilise des identifiants de session stockés dans les secrets GitHub. Il faut les remettre à jour avant chaque démonstration, sinon la CI échoue. Un rôle OIDC serait mieux, mais il est impossible à créer dans le Lab.
- **La détection de dérive** est planifiée chaque matin de semaine. Si le Lab est éteint ou que dev est détruit, ce job échouera.
- **Le Learner Lab impose `LabInstanceProfile`.** Il est trop large : une instance de dev peut lire le secret de prod. La politique idéale est décrite dans `SECURITE.md`.
- **Le bucket du state vit dans le compte de Pengchao.** Il peut disparaître si le Lab est réinitialisé.
- **Pas de HTTPS, pas de WAF, pas de logs d'accès de l'ALB.** C'est documenté et justifié dans `SECURITE.md`.
- **Les serveurs sont dans des subnets publics**, sans NAT Gateway (coût). Ils ne reçoivent du trafic que de l'ALB.
- **Le mot de passe est en clair sur le disque du serveur** (`/etc/novasphere/app.conf`, droits 0640, disque chiffré).
- **Toute exécution coûte du budget Lab.** Il faut faire `terraform destroy` après chaque test, sans toucher au bucket du state.

Signé : Pengchao Wang, Bristhis Debgeko, Serdy Adam Siassia Dekamo
