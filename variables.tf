# Parámetros del reto. Los valores por defecto son los del equipo 03,
# así que el proyecto funciona sin terraform.tfvars. Para cambiarlos,
# copiar terraform.tfvars.example a terraform.tfvars (que NO se versiona).

variable "region" {
  description = "Región de AWS donde se despliega el reto."
  type        = string
  default     = "us-east-1"
}

variable "team" {
  description = "Identificador del equipo. Forma parte del nombre del bucket."
  type        = string
  default     = "team-03"

  validation {
    condition     = can(regex("^team-[0-9]{2}$", var.team))
    error_message = "El equipo debe tener el formato team-NN (ej. team-03)."
  }
}

variable "prefix" {
  description = "Prefijo de todo lo que crea Terraform. Aísla el reto de la solución base."
  type        = string
  default     = "dcl-tf"

  validation {
    condition     = startswith(var.prefix, "dcl-tf")
    error_message = "El prefijo debe empezar por dcl-tf para no chocar con la solución base."
  }
}

variable "project" {
  description = "Nombre del proyecto (valor del tag dcl:project)."
  type        = string
  default     = "digital-cafe-luna"
}

variable "environment" {
  description = "Ambiente (valor del tag dcl:environment)."
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "Tag Name de la VPC EXISTENTE que se reutiliza (solo lectura)."
  type        = string
  default     = "dcl-dev-vpc"
}

variable "subnet_name" {
  description = "Tag Name de la subnet pública EXISTENTE que se reutiliza (solo lectura)."
  type        = string
  default     = "dcl-dev-subnet-public-a"
}

variable "instance_type" {
  description = "Tipo de instancia EC2."
  type        = string
  default     = "t3.micro"
}
