resource "aws_security_group" "sg_ssh_publico" {
  name        = "sg_ssh_publico"
  description = "Permitir acesso SSH de qualquer lugar do mundo"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH de qualquer lugar do"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg_ssh_publico"
  }
}