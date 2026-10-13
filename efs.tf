resource "aws_efs_file_system" "compartilhado" {
  encrypted = true
  tags      = { Name = "${var.project_name}-efs" }
}

resource "aws_efs_mount_target" "public" {
  file_system_id  = aws_efs_file_system.compartilhado.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.sg_efs.id]
}

resource "aws_efs_mount_target" "public_substitutiva" {
  file_system_id  = aws_efs_file_system.compartilhado.id
  subnet_id       = aws_subnet.public_substituiva.id
  security_groups = [aws_security_group.sg_efs.id]
}

locals {
  fluent_bit_config_web = templatefile("${path.module}/cloud-init/fluent-bit.yaml", {
    hostname      = "web"
    collect_nginx = true
  })

  web_user_data = replace(templatefile("${path.module}/cloud-init/web.sh", {
    efs_id                = aws_efs_file_system.compartilhado.id
    backend_private_ip    = aws_instance.instancia_app.private_ip
    fluent_bit_config_b64 = base64encode(local.fluent_bit_config_web)
    frontend_compose_b64  = base64encode(file("${path.module}/cloud-init/frontend-compose.yml"))
    deploy_frontend_script_b64 = base64encode(replace(templatefile("${path.module}/cloud-init/deploy-frontend.sh", {
      aws_region   = "us-east-1"
      ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com"
    }), "\r\n", "\n"))
  }), "\r\n", "\n")
}
