output "alb_dns_name" {
  description = "Nom DNS de l'ALB"
  value       = module.web.alb_dns_name
}

output "alb_url" {
  description = "URL de la page servie par l'ALB"
  value       = module.web.alb_url
}

output "target_group_arn" {
  description = "ARN du target group"
  value       = module.web.target_group_arn
}

output "asg_name" {
  description = "Nom de l'ASG"
  value       = module.web.asg_name
}

output "vpc_id" {
  description = "Identifiant du VPC"
  value       = module.vpc.vpc_id
}
