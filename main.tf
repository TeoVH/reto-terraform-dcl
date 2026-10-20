# Slice del reto: EC2 + Security Group + IAM Role/Instance Profile + S3.
# Todo lo creado aquí lleva el prefijo var.prefix (dcl-tf).

locals {
  bucket_name = "${var.prefix}-state-${data.aws_caller_identity.current.account_id}-${var.team}"

  common_tags = {
    "dcl:project"     = var.project
    "dcl:environment" = var.environment
    "dcl:owner-team"  = var.team
    "dcl:managed-by"  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# 1. S3: bucket privado + objeto con el estado persistente
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = true # permite que `destroy` borre el bucket aunque tenga objetos

  tags = {
    Name = local.bucket_name
  }
}

# Bloquea todo acceso público (las 4 opciones). Sin static website hosting.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "state" {
  bucket       = aws_s3_bucket.state.id
  key          = "state/dcl-state.json"
  source       = "${path.module}/files/dcl-state.json"
  etag         = filemd5("${path.module}/files/dcl-state.json") # si cambia el JSON, se vuelve a subir
  content_type = "application/json"

  tags = {
    Name = "dcl-state.json"
  }
}

# ---------------------------------------------------------------------------
# 2. IAM: policy de mínimo privilegio -> role -> instance profile
# ---------------------------------------------------------------------------

# Solo puede LEER ese único objeto. Nada de listar ni escribir.
resource "aws_iam_policy" "s3_state" {
  name        = "${var.prefix}-policy-s3-state"
  description = "Lectura del objeto state/dcl-state.json del reto Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadStateObject"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.state.arn}/${aws_s3_object.state.key}"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-policy-s3-state"
  }
}

# El role solo lo puede asumir el servicio EC2.
resource "aws_iam_role" "web" {
  name = "${var.prefix}-role-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-role-web"
  }
}

resource "aws_iam_role_policy_attachment" "web_s3_state" {
  role       = aws_iam_role.web.name
  policy_arn = aws_iam_policy.s3_state.arn
}

# El instance profile es el "contenedor" que permite entregarle el role a la EC2.
resource "aws_iam_instance_profile" "web" {
  name = "${var.prefix}-role-web"
  role = aws_iam_role.web.name

  tags = {
    Name = "${var.prefix}-role-web"
  }
}

# ---------------------------------------------------------------------------
# 3. Security Group en la VPC existente
# ---------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "${var.prefix}-sg-web"
  description = "HTTP de entrada para la EC2 del reto Terraform"
  vpc_id      = data.aws_vpc.existing.id

  tags = {
    Name = "${var.prefix}-sg-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP desde Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.prefix}-sg-web-in-http"
  }
}

# OJO: cuando Terraform crea un SG le QUITA la regla de salida por defecto.
# Por eso hay que declararla. Sin ella la EC2 no puede instalar httpd ni llegar a S3.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Toda la salida"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.prefix}-sg-web-out-all"
  }
}

# ---------------------------------------------------------------------------
# 4. EC2 (nace DESPUÉS del objeto S3 y del instance profile)
# ---------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.web.name
  associate_public_ip_address = true
  # Sin key_name: no hay SSH. Se depura con "Get system log" en la consola.

  # IMDSv2 obligatorio (el user data ya usa token).
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    bucket_name = aws_s3_bucket.state.bucket
  })
  user_data_replace_on_change = true # si cambia el script, se recrea la instancia

  volume_tags = merge(local.common_tags, {
    Name = "${var.prefix}-web-root"
  })

  tags = {
    Name = "${var.prefix}-web"
  }

  # El user data lee S3 al arrancar. El objeto y el permiso NO se referencian
  # directamente arriba, así que se fuerza el orden aquí. Si no, la página
  # mostraría "ERROR: no fue posible leer S3".
  depends_on = [
    aws_s3_object.state,
    aws_iam_role_policy_attachment.web_s3_state,
  ]
}
