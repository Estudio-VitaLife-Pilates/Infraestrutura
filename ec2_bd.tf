resource "aws_instance" "instancia_bd" {
  ami           = "ami-0b6d9d3d33ba97d99"
  instance_type = "t3.small"

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y mariadb105-server
    systemctl enable --now mariadb

    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${var.mysql_root_password}';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "FLUSH PRIVILEGES;"
  EOF

  tags = {
    Name = "InstanciaBD-01"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 20
    volume_type = "gp3"
  }

  vpc_security_group_ids = [
    aws_security_group.sg_ssh_publico.id
    ]
  
  key_name = "vockey"

}