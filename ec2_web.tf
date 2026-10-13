resource "aws_instance" "instancia_web" {
  ami                         = var.ami_id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public.id
  user_data                   = local.web_user_data
  user_data_replace_on_change = true
  iam_instance_profile        = var.instance_profile_name

  tags = {
    Name = "InstanciaWeb-01"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 8
    volume_type = "gp3"
  }

  vpc_security_group_ids = [
    aws_security_group.sg_ssh_publico.id,
    aws_security_group.sg_web.id,
  ]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_efs_mount_target.public,
    aws_efs_mount_target.public_substitutiva,
  ]

  key_name = "vockey"

}
