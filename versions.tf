terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  # Backend remoto para armazenar o estado do Terraform
  # IMPORTANTE: Configure o bucket ANTES de usar este backend
  # 1. Vá para o diretório bootstrap/
  # 2. Configure bootstrap/terraform.tfvars
  # 3. Execute: terraform init && terraform apply
  # 4. Descomente as linhas abaixo e atualize o bucket name
  # 5. Execute: terraform init -migrate-state (para migrar o estado local)

  backend "gcs" {
    bucket = "terraform-state-infra-474223"
    prefix = "terraform/state"
  }
}

