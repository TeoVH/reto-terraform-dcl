# PRERREQUISITO — solo para cuentas que NO tienen la red base de Digital Café Luna.
#
# Crea la misma red que tiene la solución base (VPC, subnet pública, IGW y ruta)
# para que cualquier integrante pueda reproducir el reto en su propia cuenta.
# Tiene su PROPIO state, separado del reto: el reto solo la lee con data sources
# y su `terraform destroy` nunca la toca.
#
# Orden: aplicar esto ANTES del reto y destruirlo DESPUÉS del destroy del reto.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "Región de la red base (debe ser la misma del reto)."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "AZ de la subnet pública. Cambiarla solo si t3.micro no está disponible en us-east-1a."
  type        = string
  default     = "us-east-1a"
}

variable "team" {
  description = "Identificador del equipo (tag dcl:owner-team)."
  type        = string
  default     = "team-03"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "dcl:project"     = "digital-cafe-luna"
      "dcl:environment" = "dev"
      "dcl:owner-team"  = var.team
      "dcl:managed-by"  = "terraform-red-base"
    }
  }
}

resource "aws_vpc" "base" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dcl-dev-vpc"
  }
}

resource "aws_internet_gateway" "base" {
  vpc_id = aws_vpc.base.id

  tags = {
    Name = "dcl-dev-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.base.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "dcl-dev-subnet-public-a"
  }
}

# Ruta 0.0.0.0/0 hacia el IGW: es lo que hace "pública" a la subnet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.base.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.base.id
  }

  tags = {
    Name = "dcl-dev-rt-public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  description = "ID de la VPC dcl-dev-vpc."
  value       = aws_vpc.base.id
}

output "subnet_id" {
  description = "ID de la subnet dcl-dev-subnet-public-a."
  value       = aws_subnet.public_a.id
}
