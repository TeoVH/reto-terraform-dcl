# Recursos que YA EXISTEN. Se leen con data sources, por lo que Terraform
# no los administra: `terraform destroy` nunca los toca y en
# `terraform state list` aparecen como data.* (no como aws_vpc / aws_subnet).

# Cuenta AWS de la sesión actual (para armar el nombre del bucket).
data "aws_caller_identity" "current" {}

# VPC de la solución base (control: 10.20.0.0/16).
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Subnet pública dentro de esa VPC (control: 10.20.1.0/24, us-east-1a).
data "aws_subnet" "public" {
  vpc_id = data.aws_vpc.existing.id

  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

# Amazon Linux 2023 más reciente (x86_64, compatible con t3.micro).
# No se fija el ID de la AMI: se busca en cada plan.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
