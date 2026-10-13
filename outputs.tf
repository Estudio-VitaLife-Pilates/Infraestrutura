output "alb_dns_name" {
  description = "DNS do load balancer (ponto de entrada da aplicacao)"
  value       = aws_lb.web.dns_name
}

output "instancia_web_ip_publico" {
  description = "IP público da instância web"
  value       = aws_instance.instancia_web.public_ip
}

output "instancia_publica_substitutiva_ip_publico" {
  description = "IP público da instância pública substitutiva"
  value       = aws_instance.instancia_publica_substitutiva.public_ip
}

output "instancia_app_ip_privado" {
  description = "IP privado do app server (nao tem IP público)"
  value       = aws_instance.instancia_app.private_ip
}

output "instancia_bd_ip_privado" {
  description = "IP privado da instância de banco de dados (não tem IP público)"
  value       = aws_instance.instancia_bd.private_ip
}

output "efs_id" {
  description = "ID do EFS compartilhado entre os web servers"
  value       = aws_efs_file_system.compartilhado.id
}

output "ecr_backend_repository_url" {
  description = "URL do repositório ECR da imagem do backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "URL do repositório ECR da imagem do frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "mysql_data_volume_id" {
  description = "Volume EBS persistente do banco de dados MySQL"
  value       = aws_ebs_volume.mysql_data.id
}

output "glue_logs_database_name" {
  description = "Nome do banco de dados Glue com o catalogo dos logs"
  value       = aws_glue_catalog_database.logs.name
}

output "glue_logs_crawler_name" {
  description = "Nome do crawler Glue dos logs"
  value       = aws_glue_crawler.logs.name
}

output "athena_logs_workgroup" {
  description = "Workgroup Athena configurado para consultar os logs"
  value       = aws_athena_workgroup.logs.name
}

output "nat_gateway_ip" {
  description = "IP publico do NAT Gateway (saida de internet da subnet privada)"
  value       = aws_eip.nat.public_ip
}
