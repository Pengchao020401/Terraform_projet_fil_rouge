# Architecture NovaSphere (brouillon P1 : infra)

> A completer par l'equipe : la partie securite (P2) et la partie livraison (P3) ajoutent leurs blocs.

## Schema

```
Internet
   |  HTTP 80
   v
[ ALB ]  groupe de securite "alb" : entree 80 depuis Internet
   |  HTTP 80 (uniquement depuis l'ALB)
   v
[ Target group ] -- health check "/" toutes les 30 s
   |
   v
[ ASG : 2 a 4 instances Debian 12 + nginx, Launch Template, IMDSv2 ]
   groupe de securite "web" : entree 80 uniquement depuis le groupe "alb"
   |
   +-- LabInstanceProfile (lit le parametre SSM du mot de passe, P2)

VPC (module du registre) : 2 zones (us-east-1a / us-east-1b), 2 subnets publics, pas de NAT Gateway
   dev  = 10.0.0.0/16        prod = 10.1.0.0/16
State : bucket S3 versionne et chiffre, une cle par env, verrou natif (use_lockfile)
```

## Les choix et leur raison
- **Subnets publics sans NAT Gateway** : la NAT facture a l'heure et le budget du Learner Lab est limite. Les instances ont une IP publique pour installer nginx, mais seul l'ALB peut les joindre sur le port 80.
- **ALB + ASG** : l'ALB repartit le trafic et ne l'envoie qu'aux instances saines ; l'ASG remplace une instance en panne.
- **Groupes de securite chaines** : le groupe "web" accepte le groupe "alb" comme source, pas une plage d'adresses. Il n'y a pas de SSH ni de cle : on n'administre pas les machines a la main.
- **Module `terraform-aws-web`** : meme code pour dev et prod, appele par un tag (`?ref=v1.0.0`) qu'on ne modifie jamais. Une correction donne un nouveau tag.
- **`LabInstanceProfile`** : le Learner Lab interdit de creer un role IAM, on utilise celui qui existe.
- **State partage dans S3** : tout le monde travaille sur le meme etat ; le verrou evite deux `apply` en meme temps.

## Limites connues
- Les ressources du state existent dans **un seul** compte AWS : c'est ce compte (celui qui a cree le bucket, ou le compte de demo) qui doit faire `apply`.
- Le lab se coupe et les identifiants changent a chaque session : `terraform destroy` a la fin de chaque session.
- HTTP seulement (pas de certificat) : voir le README du module.
