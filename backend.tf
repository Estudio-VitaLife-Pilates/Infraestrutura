terraform {
  backend "s3" {
    bucket       = "infra-pilates-bronze"
    key          = "terraform/infraestrutura/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
