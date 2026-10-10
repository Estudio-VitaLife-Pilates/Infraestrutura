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

output "nat_gateway_ip" {
  description = "IP publico do NAT Gateway (saida de internet da subnet privada)"
  value       = aws_eip.nat.public_ip
}
