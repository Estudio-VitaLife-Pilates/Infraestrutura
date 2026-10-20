terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.10"
}

provider "aws" {
  region = "us-east-1"
}

locals {
  bronze_bucket = "infra-pilates-bronze-${data.aws_caller_identity.current.account_id}"
}