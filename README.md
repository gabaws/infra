# Infraestrutura GCP - GKE com Anthos Service Mesh

Este repositório contém a infraestrutura como código (IaC) para provisionar uma infraestrutura escalável no Google Cloud Platform (GCP) com:

- **VPC** com subnets em múltiplas regiões
- **2 Clusters GKE** (master-engine e app-engine)
- **Anthos Service Mesh (ASM)** para comunicação entre clusters
- **Cloud DNS** para gerenciamento de domínio
- **Certificate Manager** para certificados SSL/TLS wildcard

## 📋 Pré-requisitos

- Terraform >= 1.3
- Conta GCP com projeto existente (`infra-474223`)
- Service Account configurado com Workload Identity para GitHub Actions
- Acesso ao projeto GCP para autenticação local

## 🚀 Início Rápido

### 1. Configuração Local

```bash
# Autenticar no GCP
gcloud auth application-default login

# Inicializar Terraform
terraform init

# Revisar o plano
terraform plan

# Aplicar a infraestrutura
terraform apply
```

### 2. Configuração do DNS

Após o provisionamento, obtenha os nameservers:

```bash
terraform output dns_nameservers
```

Configure esses nameservers no seu provedor de domínio (GoDaddy, etc.).

## 📦 O que é Provisionado

### Infraestrutura Base
- **VPC**: Rede privada com subnets em `us-central1` e `us-east1`
- **GKE Clusters**: 
  - `master-engine` (us-central1-a)
  - `app-engine` (us-east1-b)
- **Anthos Service Mesh**: Malha de serviços gerenciada para comunicação entre clusters
- **Cloud DNS**: Zona pública para `cloudab.online`
- **Certificate Manager**: Certificado wildcard `*.cloudab.online`

### O que NÃO é Provisionado
- **ArgoCD**: Deve ser instalado manualmente (veja [ARGOCD.md](ARGOCD.md))
- **Istio Ingress Gateway**: Deve ser instalado manualmente junto com o ArgoCD

## 📚 Documentação Adicional

- [Instalação Manual do ArgoCD](ARGOCD.md) - Guia completo para instalar e configurar o ArgoCD

## 🔧 Variáveis Principais

Consulte `terraform.tfvars.example` para ver todas as variáveis disponíveis.

Principais variáveis:
- `project_id`: ID do projeto GCP (padrão: `infra-474223`)
- `domain_name`: Domínio gerenciado no Cloud DNS (padrão: `cloudab.online`)
- `gke_clusters`: Configuração dos clusters GKE

## 🔄 Pipeline CI/CD

O GitHub Actions está configurado para:
- Executar `terraform plan` em Pull Requests
- Executar `terraform apply` automaticamente em pushes para `main`
- Detectar mudanças em módulos específicos e executar apenas o necessário

## 📝 Outputs Importantes

```bash
# Nameservers do DNS
terraform output dns_nameservers

# Informações dos clusters
terraform output gke_clusters

# Status do ASM
terraform output anthos_service_mesh_status

# Certificate Map ID
terraform output certificate_map_id
```

## 🗑️ Destruir Infraestrutura

```bash
terraform destroy
```

Ou via GitHub Actions: `workflow_dispatch` com `operation: destroy`

