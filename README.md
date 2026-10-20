# Reto Terraform — Digital Café Luna (team-03)

Slice desplegado con IaC: **EC2 + Security Group + IAM Role/Instance Profile + S3**, en `us-east-1`.

Una EC2 sin SSH arranca Apache y, usando su IAM role, lee un JSON privado desde S3. La página web muestra el estado **efímero** (local en la EC2) y el **persistente** (en S3). La red (VPC/subnet) de la solución base se **reutiliza** con data sources: Terraform no la crea ni la destruye.

```
Internet ──HTTP:80──▶ dcl-tf-sg-web ──▶ EC2 dcl-tf-web (AL2023, t3.micro, IMDSv2)
                                          │  instance profile dcl-tf-role-web
                                          │  (solo s3:GetObject sobre 1 objeto)
                                          ▼
                     S3 dcl-tf-state-<account-id>-team-03 / state/dcl-state.json (privado)

VPC dcl-dev-vpc + subnet dcl-dev-subnet-public-a  →  existentes, solo lectura (data.*)
```

| Capacidad que pide el reto | Cómo se cumple |
|---|---|
| Boundary de infraestructura | VPC `dcl-dev-vpc` y subnet `dcl-dev-subnet-public-a` existentes (data sources) |
| Recurso de cómputo | EC2 `dcl-tf-web` |
| Recurso dependiente real | Bucket S3 + objeto `state/dcl-state.json` que la EC2 lee al arrancar |
| Controles mínimos | Security Group (HTTP/80) + IAM role/policy/instance profile |
| Outputs para probar | IP, URL de prueba, IDs, bucket, ARN del role |

## Recursos

| Creado por Terraform (prefijo `dcl-tf`) | Solo lectura (data sources) |
|---|---|
| `aws_s3_bucket` + `aws_s3_bucket_public_access_block` + `aws_s3_object` | `data.aws_vpc.existing` (`dcl-dev-vpc`) |
| `aws_iam_policy` + `aws_iam_role` + attachment + `aws_iam_instance_profile` | `data.aws_subnet.public` (`dcl-dev-subnet-public-a`) |
| `aws_security_group` + regla de entrada 80 + regla de salida | `data.aws_ami.al2023` (AL2023 más reciente) |
| `aws_instance` | `data.aws_caller_identity.current` |

Total: **11 recursos** gestionados. Todos llevan los tags `Name`, `dcl:project`, `dcl:environment`, `dcl:owner-team` y `dcl:managed-by` (vía `default_tags`).

## Prerrequisitos

Cualquier integrante puede reproducir el reto en su propia cuenta AWS. Estos 3 pasos se hacen una sola vez por PC/cuenta.

### 1. Herramientas

Terraform `>= 1.5` y AWS CLI v2. En Windows:

```powershell
winget install --id Hashicorp.Terraform -e
winget install --id Amazon.AWSCLI -e
```

Cerrar la terminal y abrir una nueva (si no, no reconoce los comandos). Comprobar con `terraform version` y `aws --version`.

### 2. Cuenta y credenciales

- **Cuenta AWS estándar** (en Learner Lab normalmente no se pueden crear roles IAM).
- Usar un usuario IAM, no el root: IAM › Users › Create user › permiso `AdministratorAccess` › Create. Luego, en el usuario: Security credentials › Create access key › caso de uso *Command Line Interface (CLI)*.
- Configurar y comprobar:

```powershell
aws configure                # Access key, Secret key, región us-east-1, formato json
aws sts get-caller-identity  # debe mostrar el Account y el ARN del usuario
```

Las llaves quedan en el perfil de AWS del PC (`%USERPROFILE%\.aws\credentials`), nunca en esta carpeta.

### 3. Red base

El reto reutiliza la red de la solución base: VPC `dcl-dev-vpc` (10.20.0.0/16) y subnet `dcl-dev-subnet-public-a` (10.20.1.0/24, us-east-1a) con ruta `0.0.0.0/0` al IGW `dcl-dev-igw`. Comprobar si existe en la cuenta:

```powershell
aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=dcl-dev-vpc --query "Vpcs[].VpcId" --output text
```

- **Si imprime un ID** (`vpc-...`): la red ya existe; pasar a *Uso*.
- **Si no imprime nada** (cuenta personal): crearla con `red-base/`. Esa carpeta tiene su **propio state**, separado del reto, así que el reto la sigue viendo como red existente (solo `data.*`):

```powershell
cd red-base
terraform init
terraform apply   # revisar y escribir yes: crea 5 recursos de red
cd ..
```

## Variables

Todas tienen valor por defecto para team-03, así que **no hace falta `terraform.tfvars`**. Para cambiar algo, copiar `terraform.tfvars.example` a `terraform.tfvars` (ese archivo no se versiona).

| Variable | Defecto | Uso |
|---|---|---|
| `region` | `us-east-1` | Región |
| `team` | `team-03` | Nombre del bucket y tag (valida formato `team-NN`) |
| `prefix` | `dcl-tf` | Prefijo de todo lo creado (valida que empiece por `dcl-tf`) |
| `project` | `digital-cafe-luna` | Tag `dcl:project` |
| `environment` | `dev` | Tag `dcl:environment` |
| `vpc_name` | `dcl-dev-vpc` | VPC existente a reutilizar |
| `subnet_name` | `dcl-dev-subnet-public-a` | Subnet existente a reutilizar |
| `instance_type` | `t3.micro` | Tipo de EC2 |

## Uso (ciclo completo con evidencias)

Ejecutar desde esta carpeta; los comandos funcionan igual en PowerShell y en bash. La evidencia de cada gate es una **captura de pantalla** guardada en `evidencias/` con el número del gate (`01-init.png`, `02-validate.png`, …). Usar `cls` antes de cada comando para que la captura quede limpia. `evidencias/REGISTRO.md` las muestra todas.

```powershell
# 1. Init
terraform init

# 2. Validate (+ formato: no debe imprimir nada)
terraform fmt -check -recursive
terraform validate

# 3. Plan (esperado: "Plan: 11 to add, 0 to change, 0 to destroy")
terraform plan -out=tfplan

# 4. Apply del plan revisado
terraform apply tfplan
```

## Validación (functional check)

Esperar **1 o 2 minutos** después del apply, porque la EC2 instala Apache y lee S3.

```powershell
curl.exe -s $(terraform output -raw test_url)
```

(En Linux/macOS usar `curl` en vez de `curl.exe`.)

**PASS** si la página muestra el Instance ID, la AZ (`us-east-1a`) y, bajo *Estado persistente en S3*, el JSON con `"message": "Estado persistente almacenado fuera de EC2"`. **FAIL** si aparece `ERROR: no fue posible leer S3`. Capturas: la terminal (`05-functional-check-terminal.png`) y el navegador abriendo `http://<IP>` (`05-functional-check.png`).

## Cleanup

Primero confirmar que el state solo tiene recursos del reto (solo `data.*` y recursos `dcl-tf`, ningún `aws_vpc` ni `aws_subnet`):

```powershell
terraform state list

# Este comando NO debe imprimir nada (PowerShell):
terraform state list | Select-String -Pattern '^aws_(vpc|subnet)\.'
# Equivalente en bash: terraform state list | grep -E '^aws_(vpc|subnet)\.'
```

Luego destruir (esperado: `Destroy complete! Resources: 11 destroyed.`) y comprobar que la red base sigue en pie:

```powershell
terraform destroy -auto-approve   # la revisión es el state list anterior
aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=dcl-dev-vpc --query "Vpcs[].[VpcId,CidrBlock]" --output text
```

Si la red se creó con `red-base/`, eliminarla al final y **solo después** del destroy del reto (antes, AWS lo rechaza porque la VPC todavía está en uso):

```powershell
cd red-base
terraform destroy   # escribir yes: elimina los 5 recursos de red
cd ..
```

Al final, llenar `evidencias/REGISTRO.md` con PASS/FAIL por gate.

## Problemas frecuentes

| Síntoma | Causa probable / solución |
|---|---|
| La página muestra `ERROR: no fue posible leer S3` | El role tarda unos segundos en propagarse y la EC2 arrancó antes. Recrear solo la instancia: `terraform apply "-replace=aws_instance.web"`. Para ver qué pasó sin SSH: consola EC2 › Actions › Monitor and troubleshoot › Get system log. |
| La página no carga | Esperar 2 minutos, usar `http://` (no https) y revisar que la subnet tenga ruta al IGW. |
| `no matching EC2 VPC found` | La red base no existe en esa cuenta/región: ver *Prerrequisitos › 3. Red base*. |
| `multiple EC2 VPCs matched` | Hay dos VPC con el nombre `dcl-dev-vpc` (por ejemplo, se aplicó `red-base/` en una cuenta que ya tenía la red). Destruir la de `red-base/`. |
| `t3.micro ... is not supported in your requested Availability Zone` | En `red-base/`: `terraform apply -var "availability_zone=us-east-1b"` y repetir el ciclo del reto. |
| `AccessDenied` al crear IAM | Cuenta Learner Lab o usuario sin permisos IAM; se necesita cuenta estándar. |
| `terraform` o `aws` no se reconoce | Instalar (ver *Prerrequisitos*) y abrir una terminal nueva. |

## Seguridad e información sensible

- **Sin secretos en el código**: credenciales solo por perfil o entorno; `terraform.tfvars`, `*.tfstate*` y `.terraform/` en `.gitignore`. Antes de entregar, revisar que las evidencias no tengan access keys ni tokens.
- **Mínimo privilegio**: la EC2 solo puede `s3:GetObject` sobre `state/dcl-state.json`; no puede listar ni escribir.
- **Bucket privado**: las 4 opciones de *Block Public Access* activas, sin static hosting.
- **IMDSv2 obligatorio** (`http_tokens = "required"`), **sin key pair** (sin SSH) y disco raíz cifrado.
- **Security Group**: solo entra HTTP/80. La regla de salida se declara explícitamente porque Terraform elimina la salida por defecto al crear un SG.
- **Orden de creación**: `depends_on` en la EC2 garantiza que el objeto S3 y el permiso existan antes de que corra el user data.
- **Aislamiento**: prefijo `dcl-tf` validado y red por data sources, así `destroy` nunca toca la solución base que se defiende en S16.

## Estructura

```
reto-terraform-dcl/
├── versions.tf               # Terraform >= 1.5, provider aws ~> 6.0
├── providers.tf              # región + default_tags
├── variables.tf              # parámetros con validaciones
├── data.tf                   # VPC, subnet, AMI y cuenta existentes (solo lectura)
├── main.tf                   # S3, IAM, SG y EC2
├── outputs.tf                # IDs, IP, URL de prueba, bucket, role, SG
├── templates/user_data.sh.tftpl
├── files/dcl-state.json
├── red-base/main.tf          # prerrequisito: red base para cuentas personales (state propio)
├── terraform.tfvars.example
├── .gitignore
├── .gitattributes            # user data siempre con saltos de línea LF
├── README.md
└── evidencias/               # capturas de cada gate + REGISTRO.md
```

Se sigue la estructura sugerida del reto; solo se separan `data.tf` (para que se vea qué es de solo lectura), la plantilla del user data y el JSON del estado. `red-base/` es un prerrequisito opcional: no forma parte del slice ni de su state.
