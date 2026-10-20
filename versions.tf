# Versiones mínimas de Terraform y del provider de AWS.
# El archivo .terraform.lock.hcl que genera `terraform init` SÍ se versiona:
# fija la versión exacta del provider para que todo el equipo use la misma.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
