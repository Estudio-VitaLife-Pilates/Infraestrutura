resource "aws_security_group" "sg_ssh_publico" {
  name        = "sg_ssh_publico"
  description = "Permitir acesso SSH de qualquer lugar do mundo"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH de qualquer lugar do"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg_ssh_publico"
  }
}

resource "aws_security_group" "sg_web" {
  name        = "sg_web"
  description = "Permitir trafego HTTP/HTTPS de qualquer lugar"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_web"
  }
}

resource "aws_security_group" "sg_efs" {
  name        = "sg_efs"
  description = "Permitir NFS (EFS) a partir dos web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS a partir dos web servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ssh_publico.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_efs"
  }
}

resource "aws_security_group" "sg_app" {
  name        = "sg_app"
  description = "Trafego da aplicacao vindo dos web servers, SSH interno"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App (8080) a partir dos web servers"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ssh_publico.id]
  }

  ingress {
    description = "SSH somente da rede interna da VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_app"
  }
}

resource "aws_security_group" "sg_bd" {
  name        = "sg_bd"
  description = "Acesso interno ao banco de dados (SSH da VPC, MySQL do app server)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH somente da rede interna da VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  ingress {
    description     = "MySQL a partir do app server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_bd"
  }
}
