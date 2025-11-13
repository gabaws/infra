# Bootstrap - Criação do Bucket de Estado

Este diretório contém o código para criar o bucket GCS que armazenará o estado do Terraform.

## ⚠️ Importante

**Execute este módulo ANTES de configurar o backend remoto no Terraform principal!**

O Terraform precisa que o bucket exista antes de poder usá-lo como backend.

## 🚀 Como Usar

### 1. Configurar Variáveis

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:

```hcl
bootstrap_project_id = "seu-projeto-bootstrap"  # Pode ser um projeto separado
bucket_name          = "terraform-state-bucket-seu-projeto"
bucket_location      = "US"  # ou região específica
```

### 2. Aplicar

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configurar Backend no Terraform Principal

Após criar o bucket:

1. Edite `../versions.tf` na raiz do projeto
2. Descomente o bloco `backend "gcs"`
3. Atualize o nome do bucket
4. Execute na raiz: `terraform init -migrate-state`

## 📋 O que é Criado

- ✅ Bucket GCS com nome único
- ✅ Versioning habilitado (mantém 5 versões)
- ✅ Uniform bucket-level access
- ✅ Labels apropriados

## 🔒 Segurança

O bucket é criado com:
- Versioning para histórico
- IAM configurável (via variáveis)
- Encryption (opcional, via KMS)

## 🧹 Limpeza

Para remover o bucket (cuidado - isso apaga o estado!):

```bash
terraform destroy
```

Ou configure `force_destroy = true` no módulo para permitir remoção mesmo com objetos.

## 📚 Próximos Passos

Após criar o bucket, volte para a raiz do projeto e configure o backend em `versions.tf`.

