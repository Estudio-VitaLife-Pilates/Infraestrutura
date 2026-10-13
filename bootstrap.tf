data "aws_caller_identity" "current" {}

locals {
  aws_region   = "us-east-1"
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com"

  fluent_bit_config_app = templatefile("${path.module}/cloud-init/fluent-bit.yaml", {
    hostname      = "app"
    collect_nginx = false
  })
  fluent_bit_config_database = templatefile("${path.module}/cloud-init/fluent-bit.yaml", {
    hostname      = "database"
    collect_nginx = false
  })

  app_bootstrap = replace(templatefile("${path.module}/cloud-init/app.sh", {
    fluent_bit_config_b64 = base64encode(local.fluent_bit_config_app)
    backend_compose_b64   = base64encode(templatefile("${path.module}/cloud-init/backend-compose.yml", {}))
    deploy_script_b64 = base64encode(replace(templatefile("${path.module}/cloud-init/deploy-backend.sh", {
      aws_region   = local.aws_region
      ecr_registry = local.ecr_registry
    }), "\r\n", "\n"))
    database_host = aws_instance.instancia_bd.private_ip
  }), "\r\n", "\n")

  database_bootstrap = replace(templatefile("${path.module}/cloud-init/database.sh", {
    fluent_bit_config_b64 = base64encode(local.fluent_bit_config_database)
    database_compose_b64  = base64encode(templatefile("${path.module}/cloud-init/database-compose.yml", {}))
    volume_serial         = replace(aws_ebs_volume.mysql_data.id, "-", "")
  }), "\r\n", "\n")
}

resource "aws_ebs_volume" "mysql_data" {
  availability_zone = aws_subnet.private.availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-mysql-data"
  }
}

resource "aws_s3_object" "app_bootstrap" {
  bucket       = "infra-pilates-bronze"
  key          = "bootstrap/infra-pilates/app.sh"
  content      = local.app_bootstrap
  content_type = "text/x-shellscript"
  etag         = md5(local.app_bootstrap)
}

resource "aws_s3_object" "database_bootstrap" {
  bucket       = "infra-pilates-bronze"
  key          = "bootstrap/infra-pilates/database.sh"
  content      = local.database_bootstrap
  content_type = "text/x-shellscript"
  etag         = md5(local.database_bootstrap)
}

resource "aws_volume_attachment" "mysql_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mysql_data.id
  instance_id = aws_instance.instancia_bd.id
}

resource "aws_ssm_association" "app_bootstrap" {
  name             = "AWS-RunShellScript"
  association_name = "${var.project_name}-app-bootstrap"
  max_concurrency  = "1"
  max_errors       = "0"

  targets {
    key    = "tag:Name"
    values = ["InstanciaApp-01"]
  }

  parameters = {
    commands = "echo 'App bootstrap revision ${aws_s3_object.app_bootstrap.etag}' && apt-get update && apt-get install -y awscli && aws s3 cp --region ${local.aws_region} s3://infra-pilates-bronze/bootstrap/infra-pilates/app.sh /tmp/infra-pilates-app-bootstrap.sh && sed -i 's/\\r$//' /tmp/infra-pilates-app-bootstrap.sh && bash /tmp/infra-pilates-app-bootstrap.sh"
  }

  depends_on = [
    aws_instance.instancia_app,
    aws_s3_object.app_bootstrap,
  ]
}

resource "aws_ssm_association" "database_bootstrap" {
  name             = "AWS-RunShellScript"
  association_name = "${var.project_name}-database-bootstrap"
  max_concurrency  = "1"
  max_errors       = "0"

  targets {
    key    = "tag:Name"
    values = ["InstanciaBD-01"]
  }

  parameters = {
    commands = "apt-get update && apt-get install -y awscli && aws s3 cp --region ${local.aws_region} s3://infra-pilates-bronze/bootstrap/infra-pilates/database.sh /tmp/infra-pilates-database-bootstrap.sh && sed -i 's/\\r$//' /tmp/infra-pilates-database-bootstrap.sh && bash /tmp/infra-pilates-database-bootstrap.sh"
  }

  depends_on = [
    aws_s3_object.database_bootstrap,
    aws_volume_attachment.mysql_data,
    aws_instance.instancia_bd,
  ]
}
