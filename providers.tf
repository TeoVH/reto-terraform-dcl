# Provider de AWS.
# Las credenciales NO van aquí: se toman del entorno (aws configure / AWS_PROFILE
# / variables de entorno). Así no queda ningún secreto en el código.

provider "aws" {
  region = var.region

  # Tags que se aplican automáticamente a TODO recurso que los admita.
  # El tag "Name" se pone en cada recurso porque cambia de uno a otro.
  default_tags {
    tags = local.common_tags
  }
}
