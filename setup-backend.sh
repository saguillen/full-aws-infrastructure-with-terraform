#!/bin/bash

# Script para crear los recursos necesarios para el backend de Terraform
# Tabla DynamoDB para locks y Bucket S3 para el state
#
# Uso:
#   ./setup-backend.sh [AWS_PROFILE] [AWS_REGION]
#
# Ejemplo:
#   ./setup-backend.sh eusebiomesas-sso eu-west-1

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar uso
show_usage() {
    echo -e "${BLUE}Uso:${NC}"
    echo -e "  $0 [AWS_PROFILE] [AWS_REGION]"
    echo ""
    echo -e "${BLUE}Parámetros:${NC}"
    echo -e "  AWS_PROFILE      - Perfil de AWS CLI a utilizar"
    echo -e "  AWS_REGION       - Región de AWS donde crear los recursos"
    echo -e "  DYNAMODB_TABLE   - Nombre de la tabla DynamoDB para locks (opcional)"
    echo -e "  S3_BUCKET        - Nombre del bucket S3 para el state (opcional)"
    echo ""
    echo -e "${BLUE}Ejemplos:${NC}"
    echo -e "  # Usar valores por defecto (nombres automáticos con región y account_id)"
    echo -e "  $0"
    echo ""
    echo -e "  # Especificar solo perfil y región"
    echo -e "  $0 mi-perfil us-east-1"
    echo ""
    echo -e "  # Especificar nombres personalizados"
    echo -e "  $0 mi-perfil us-east-1 mi-tabla-locks mi-bucket-state"
    echo ""
    echo -e "${BLUE}Valores por defecto:${NC}"
    echo -e "  AWS_PROFILE:     eusebiomesas-sso"
    echo -e "  AWS_REGION:      us-east-1"
    echo -e "  DYNAMODB_TABLE:  master-cloud-terraform-state-locks-<REGION>-<ACCOUNT_ID>"
    echo -e "  S3_BUCKET:       master-cloud-terraform-state-<REGION>-<ACCOUNT_ID>"
    echo -e "  "
    echo -e "  Donde <REGION> y <ACCOUNT_ID> se obtienen automáticamente de tu configuración AWS."
    echo ""
    echo -e "${BLUE}Nota:${NC}"
    echo -e "  El script también actualizará automáticamente el archivo backend.tf"
    echo -e "  con los valores configurados."
    echo ""
}

# Mostrar ayuda si se solicita
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Configuración - Usar parámetros o valores por defecto
AWS_PROFILE="${1:-default}"
AWS_REGION="${2:-us-east-2}"

# Verificar que AWS CLI está configurado
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup Terraform Backend Resources${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}[1/5] Verificando configuración de AWS CLI...${NC}"
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
    echo -e "${RED}Error: No se puede autenticar con AWS usando el perfil $AWS_PROFILE${NC}"
    echo -e "${YELLOW}Ejecuta: aws sso login --profile $AWS_PROFILE${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
echo -e "${GREEN}✓ Autenticado correctamente (Account: $ACCOUNT_ID)${NC}"
echo ""

# Construir nombres de recursos basados en región y account_id
DYNAMODB_TABLE="master-cloud-terraform-state-locks-${AWS_REGION}-${ACCOUNT_ID}"
S3_BUCKET="master-cloud-terraform-state-${AWS_REGION}-${ACCOUNT_ID}"

echo -e "${BLUE}Configuración:${NC}"
echo -e "  AWS Profile:     ${GREEN}$AWS_PROFILE${NC}"
echo -e "  AWS Region:      ${GREEN}$AWS_REGION${NC}"
echo -e "  Account ID:      ${GREEN}$ACCOUNT_ID${NC}"
echo -e "  DynamoDB Table:  ${GREEN}$DYNAMODB_TABLE${NC}"
echo -e "  S3 Bucket:       ${GREEN}$S3_BUCKET${NC}"
echo ""

# Crear tabla DynamoDB para locks
echo -e "${YELLOW}[2/5] Creando tabla DynamoDB: $DYNAMODB_TABLE...${NC}"

# Verificar si la tabla ya existe
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --profile "$AWS_PROFILE" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${GREEN}✓ La tabla DynamoDB ya existe${NC}"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=MasterCloud Key=ManagedBy,Value=Script Key=Purpose,Value=TerraformStateLock \
        > /dev/null
    
    echo -e "${YELLOW}Esperando a que la tabla esté activa...${NC}"
    aws dynamodb wait table-exists \
        --table-name "$DYNAMODB_TABLE" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"
    
    echo -e "${GREEN}✓ Tabla DynamoDB creada exitosamente${NC}"
fi
echo ""

# Crear bucket S3 para el state
echo -e "${YELLOW}[3/5] Creando bucket S3: $S3_BUCKET...${NC}"

# Verificar si el bucket ya existe
if aws s3api head-bucket --bucket "$S3_BUCKET" --profile "$AWS_PROFILE" 2> /dev/null; then
    echo -e "${GREEN}✓ El bucket S3 ya existe${NC}"
else
    # Crear el bucket
    if [ "$AWS_REGION" = "us-east-1" ]; then
        # us-east-1 no requiere LocationConstraint
        aws s3api create-bucket \
            --bucket "$S3_BUCKET" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            > /dev/null
    else
        # Otras regiones requieren LocationConstraint
        aws s3api create-bucket \
            --bucket "$S3_BUCKET" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION" \
            > /dev/null
    fi
    
    echo -e "${GREEN}✓ Bucket S3 creado exitosamente${NC}"
fi
echo ""

# Configurar versionado y encriptación del bucket
echo -e "${YELLOW}[4/5] Configurando bucket S3...${NC}"

# Habilitar versionado
echo -e "  - Habilitando versionado..."
aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --versioning-configuration Status=Enabled \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

# Habilitar encriptación
echo -e "  - Habilitando encriptación AES256..."
aws s3api put-bucket-encryption \
    --bucket "$S3_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": false
        }]
    }' \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

# Bloquear acceso público
echo -e "  - Bloqueando acceso público..."
aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

# Añadir tags al bucket
echo -e "  - Añadiendo tags..."
aws s3api put-bucket-tagging \
    --bucket "$S3_BUCKET" \
    --tagging 'TagSet=[
        {Key=Project,Value=MasterCloud},
        {Key=ManagedBy,Value=Script},
        {Key=Purpose,Value=TerraformState}
    ]' \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

echo -e "${GREEN}✓ Bucket S3 configurado exitosamente${NC}"
echo ""

# Actualizar backend.tf con los nombres de recursos
echo -e "${YELLOW}[5/5] Actualizando backend.tf...${NC}"

BACKEND_FILE="backend.tf"
if [ -f "$BACKEND_FILE" ]; then
    # Crear backup del archivo original
    cp "$BACKEND_FILE" "${BACKEND_FILE}.backup"
    
    # Actualizar los valores en backend.tf
    sed -i "s|bucket[[:space:]]*=[[:space:]]*\".*\"|bucket         = \"$S3_BUCKET\"|g" "$BACKEND_FILE"
    sed -i "s|dynamodb_table[[:space:]]*=[[:space:]]*\".*\"|dynamodb_table = \"$DYNAMODB_TABLE\"|g" "$BACKEND_FILE"
    sed -i "s|region[[:space:]]*=[[:space:]]*\".*\"|region         = \"$AWS_REGION\"|g" "$BACKEND_FILE"
    sed -i "s|profile[[:space:]]*=[[:space:]]*\".*\"|profile        = \"$AWS_PROFILE\"|g" "$BACKEND_FILE"
    
    echo -e "${GREEN}✓ backend.tf actualizado${NC}"
    echo -e "  Backup guardado en: ${YELLOW}${BACKEND_FILE}.backup${NC}"
else
    echo -e "${YELLOW}⚠ No se encontró backend.tf en el directorio actual${NC}"
fi
echo ""

# Resumen
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Setup completado exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Recursos creados:${NC}"
echo -e "  • Tabla DynamoDB: ${GREEN}$DYNAMODB_TABLE${NC}"
echo -e "    - Región: $AWS_REGION"
echo -e "    - Billing: PAY_PER_REQUEST"
echo ""
echo -e "  • Bucket S3: ${GREEN}$S3_BUCKET${NC}"
echo -e "    - Región: $AWS_REGION"
echo -e "    - Versionado: Habilitado"
echo -e "    - Encriptación: AES256"
echo -e "    - Acceso público: Bloqueado"
echo ""
echo -e "${YELLOW}Configuración del backend:${NC}"
echo -e "  • Profile: ${GREEN}$AWS_PROFILE${NC}"
echo -e "  • Region:  ${GREEN}$AWS_REGION${NC}"
echo -e "  • Bucket:  ${GREEN}$S3_BUCKET${NC}"
echo -e "  • Table:   ${GREEN}$DYNAMODB_TABLE${NC}"
echo ""
echo -e "${YELLOW}Ahora puedes ejecutar:${NC}"
echo -e "  ${BLUE}terraform init${NC}"
echo ""