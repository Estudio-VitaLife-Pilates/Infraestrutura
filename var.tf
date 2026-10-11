variable "ami_id" {
  description = "AMI usada por todas as instâncias EC2"
  type        = string
  default     = "ami-0b6d9d3d33ba97d99"
}

variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos"
  type        = string
  default     = "infra-pilates"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name deve conter apenas letras minúsculas, números e hífens, entre 3 e 30 caracteres."
  }
}

variable "instance_profile_name" {
  description = "Nome do instance profile IAM (ja existente na conta) usado pelo app server e pelo db instance -- ex: para acessar o S3 no futuro. No Learner Lab isso normalmente ja existe como \"LabInstanceProfile\" -- criar um novo role/profile costuma ser bloqueado por permissao."
  type        = string
  default     = "LabInstanceProfile"
}
