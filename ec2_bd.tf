resource "aws_instance" "instancia_bd" {
  ami           = "ami-0b6d9d3d33ba97d99"
  instance_type = "t3.small"

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