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
- **Anthos Service Mesh (ASM)**: Malha de serviços gerenciada para comunicação entre clusters
- **Cloud DNS**: Zona pública para `cloudab.online`
- **Certificate Manager**: Certificado wildcard `*.cloudab.online`

### O que é Provisionado (Fleet e ASM)
- **GKE Hub Fleet**: Os clusters são automaticamente registrados no Fleet
- **Anthos Service Mesh (ASM)**: Habilitado automaticamente em todos os clusters com gerenciamento automático
- Os clusters compartilham a mesma malha de serviços (mesh) para comunicação segura entre clusters


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

## ⚠️ Troubleshooting

### Erro: "Already exists" ao recriar clusters GKE

**Problema**: Após destruir os clusters GKE, ao tentar recriá-los imediatamente, você pode receber o erro:
```
Error: googleapi: Error 409: Already exists: projects/.../clusters/...
```

**Causa**: O GCP precisa de tempo (geralmente 5-15 minutos) para limpar completamente os recursos do cluster após a exclusão. Durante esse período, o cluster ainda existe no sistema do GCP, mesmo que apareça como "deletado" no console.

**Soluções**:

1. **Aguardar a limpeza completa** (Recomendado):
   ```bash
   # Verificar se os clusters foram completamente removidos
   gcloud container clusters list --project=infra-474223
   
   # Aguardar até que a lista esteja vazia (pode levar 5-15 minutos)
   # Depois, executar novamente:
   terraform apply
   ```

2. **Verificar o estado do Terraform**:
   ```bash
   # Verificar se há recursos órfãos no estado
   terraform state list
   
   # Se necessário, remover manualmente do estado
   terraform state rm module.gke_clusters[0].google_container_cluster.clusters["master-engine"]
   terraform state rm module.gke_clusters[0].google_container_cluster.clusters["app-engine"]
   ```

3. **Forçar remoção manual** (se o cluster estiver travado):
   ```bash
   # Remover o cluster manualmente via gcloud
   gcloud container clusters delete master-engine --zone=us-central1-a --project=infra-474223 --quiet
   gcloud container clusters delete app-engine --zone=us-east1-b --project=infra-474223 --quiet
   
   # Aguardar a remoção completa e então executar:
   terraform apply
   ```

4. **Usar nomes diferentes temporariamente**:
   Se precisar recriar imediatamente, altere temporariamente os nomes dos clusters em `terraform.tfvars`:
   ```hcl
   gke_clusters = {
     master-engine-v2 = { ... }
     app-engine-v2 = { ... }
   }
   ```

**Prevenção**: Os timeouts foram configurados no módulo GKE para garantir que a destruição seja completa. Se o problema persistir, aguarde pelo menos 10 minutos após a destruição antes de tentar recriar.

## 🔗 Anthos Service Mesh (ASM)

O projeto provisiona automaticamente:

1. **Registro no Fleet**: Ambos os clusters são registrados automaticamente no GKE Hub Fleet
2. **Anthos Service Mesh**: A feature do ASM é habilitada no Fleet e configurada com gerenciamento automático
3. **Feature Membership**: Cada cluster é registrado na feature do ASM para compartilhar a mesma malha de serviços

### Como Funciona

- Os clusters `master-engine` e `app-engine` fazem parte da mesma **malha de serviços (mesh)**
- Comunicação entre clusters é feita através do ASM com mTLS automático
- O gerenciamento é automático (`MANAGEMENT_AUTOMATIC`), então o ASM é instalado e mantido automaticamente pelo Google Cloud

### Verificar Status do ASM

```bash
# Verificar status da feature do ASM
gcloud container hub features describe servicemesh --project=infra-474223 --location=global

# Verificar memberships dos clusters
terraform output anthos_service_mesh_status

# Listar clusters no Fleet
gcloud container fleet memberships list --project=infra-474223
```

### Notas Importantes

- ✅ O ASM é provisionado automaticamente via Terraform
- ✅ Ambos os clusters compartilham a mesma malha de serviços
- ✅ mTLS é habilitado automaticamente para comunicação segura entre clusters
- ℹ️ Exemplos de uso estão disponíveis em `mcs-demo/` (não fazem parte do provisionamento)

## 🌐 Multi-cluster Ingress

O **Multi-cluster Ingress** permite expor serviços de múltiplos clusters GKE através de um único ponto de entrada com balanceamento de carga global.

**⚠️ Importante**: O Multi-cluster Ingress **não é suportado pelo Terraform** e deve ser habilitado manualmente via `gcloud` após o provisionamento da infraestrutura.

### Documentação

Para instruções detalhadas sobre como habilitar o Multi-cluster Ingress, consulte: **[docs/MULTICLUSTER_INGRESS.md](./docs/MULTICLUSTER_INGRESS.md)**

### Notas Importantes

- ⚠️ O Multi-cluster Ingress **não é suportado pelo Terraform** e deve ser habilitado manualmente
- Requer um **config cluster** que gerencia a configuração do ingress
- Todos os clusters devem estar registrados no mesmo **GKE Hub Fleet**
- Após habilitar, pode levar alguns minutos para a propagação completa

