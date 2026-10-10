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
  efs_mount_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y amazon-efs-utils
    mkdir -p /mnt/compartilhado
    echo "${aws_efs_file_system.compartilhado.id}:/ /mnt/compartilhado efs _netdev,tls 0 0" >> /etc/fstab
    mount -a -t efs
  EOF
}
