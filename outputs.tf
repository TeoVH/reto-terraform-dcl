output "instance_id" {
  description = "ID de la instancia EC2."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "IP pública de la instancia."
  value       = aws_instance.web.public_ip
}

output "test_url" {
  description = "URL del functional check (esperar 1-2 minutos tras el apply)."
  value       = "http://${aws_instance.web.public_ip}"
}

output "bucket_name" {
  description = "Bucket S3 con el estado persistente."
  value       = aws_s3_bucket.state.bucket
}

output "role_arn" {
  description = "ARN del IAM role de la instancia."
  value       = aws_iam_role.web.arn
}

output "security_group_id" {
  description = "ID del Security Group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "AMI de Amazon Linux 2023 resuelta en este despliegue."
  value       = data.aws_ami.al2023.id
}

# Evidencia de que la red se REUTILIZA (data source), no se crea.
output "reused_network" {
  description = "VPC y subnet existentes reutilizadas (solo lectura)."
  value = {
    vpc_id      = data.aws_vpc.existing.id
    vpc_cidr    = data.aws_vpc.existing.cidr_block
    subnet_id   = data.aws_subnet.public.id
    subnet_cidr = data.aws_subnet.public.cidr_block
    subnet_az   = data.aws_subnet.public.availability_zone
  }
}
