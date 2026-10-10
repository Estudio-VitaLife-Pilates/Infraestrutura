resource "aws_instance" "instancia_publica_substitutiva" {
  ami           = var.ami_id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_substituiva.id
  user_data     = local.efs_mount_user_data

  tags = {
    Name = "InstanciaPub-Substitutiva-01"
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

  key_name = "vockey"

}
