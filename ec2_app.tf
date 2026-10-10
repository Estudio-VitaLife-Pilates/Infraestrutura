resource "aws_instance" "instancia_app" {
  ami                  = var.ami_id
  instance_type        = "t3.small"
  subnet_id            = aws_subnet.private.id
  iam_instance_profile = var.instance_profile_name

  tags = {
    Name = "InstanciaApp-01"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 8
    volume_type = "gp3"
  }

  vpc_security_group_ids = [
    aws_security_group.sg_app.id,
  ]

  key_name = "vockey"
}
