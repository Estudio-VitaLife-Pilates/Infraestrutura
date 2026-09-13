variable "vpc_id" {
  description = "ID da VPC" #não pode ter caractere especial
  type = string
  default = "vpc-03d1196d9a8a872d4"
}

variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos e buckets"
  type        = string
  default     = "infra-pilates"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name deve conter apenas letras minúsculas, números e hífens, entre 3 e 30 caracteres."
  }
}

variable "tags" {
  description = "Tags aplicadas aos buckets da camada analítica"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "mysql_root_password" {
  description = "Senha inicial do usuário root do MySQL"
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.mysql_root_password) >= 12
    error_message = "mysql_root_password deve ter pelo menos 12 caracteres."
  }
}