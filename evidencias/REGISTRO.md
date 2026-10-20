# Registro compacto de ejecución — team-03

Fecha de ejecución: `2026-10-20` · Responsable: `Mateo Villada` · Terraform `v1.16.6` · Provider `hashicorp/aws v6.69.1` · Región `us-east-1`

Cuenta AWS estándar personal. La red base no existía en esa cuenta, así que se creó antes con `red-base/` (5 recursos, state propio y separado del reto) y se elimina después del destroy del reto.

| Gate | Resultado | Evidencia / referencia |
|---|---|---|
| terraform init | PASS | `01-init.txt` — "Terraform has been successfully initialized!" |
| terraform validate | PASS | `02-validate.txt` — "Success! The configuration is valid." (además `terraform fmt -check -recursive` sin diferencias) |
| terraform plan | PASS | `03-plan.txt` — "Plan: 11 to add, 0 to change, 0 to destroy."; la VPC y la subnet aparecen solo como `data.*` |
| terraform apply | PASS | `04-apply.txt` — "Apply complete! Resources: 11 added, 0 changed, 0 destroyed."; `04-outputs.txt` — `test_url = http://100.58.210.143` |
| functional check | PASS | `05-functional-check.html` y `05-functional-check.png` — la página muestra Instance ID `i-056f4b5cf1e566e16`, AZ `us-east-1a`, el estado local y el JSON leído de S3 (sin el mensaje de error) |
| terraform destroy / cleanup | PASS | `06-state-list.txt` — solo 4 `data.*` y los 11 recursos del reto, ningún `aws_vpc` ni `aws_subnet`; `07-destroy.txt` — "Destroy complete! Resources: 11 destroyed."; `08-vpc-intacta.txt` — `vpc-0d217b777ec087cfe 10.20.0.0/16` sigue existiendo después del destroy |

Las evidencias no contienen access keys, secret keys ni tokens.
