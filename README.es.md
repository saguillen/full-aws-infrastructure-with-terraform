# Infraestructura AWS con Terraform



shell

![alt text](image.png)


![alt text](image-1.png)


```shell
Recursos creados:
  • Tabla DynamoDB: master-cloud-terraform-state-locks-us-east-2-005423366133
    - Región: us-east-2
    - Billing: PAY_PER_REQUEST

  • Bucket S3: master-cloud-terraform-state-us-east-2-005423366133
    - Región: us-east-2
    - Versionado: Habilitado
    - Encriptación: AES256
    - Acceso público: Bloqueado

Configuración del backend:
  • Profile: default
  • Region:  us-east-2
  • Bucket:  master-cloud-terraform-state-us-east-2-005423366133
  • Table:   master-cloud-terraform-state-locks-us-east-2-005423366133

Ahora puedes ejecutar:
  terraform init
```


## Archibo backend.tf
```
terraform {
  backend "s3" {
    profile        = "default"
    bucket         = "master-cloud-terraform-state-us-east-2-005423366133"
    key            = "06-demo-final/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "master-cloud-terraform-state-locks-us-east-2-005423366133"
    encrypt        = true
  }
}
```


## Despues de correr terraform init
```shell
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 4.0.0"...
- Installing hashicorp/aws v6.27.0...
- Installed hashicorp/aws v6.27.0 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

