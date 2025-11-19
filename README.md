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

### O que NÃO é Provisionado
- **Multi-cluster Services (MCS)**: Deve ser habilitado manualmente (veja seção [MCS](#-multi-cluster-services-mcs))


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

## 🔗 Multi-cluster Services (MCS)

O **Multi-cluster Services (MCS)** é uma feature do projeto que permite comunicação transparente entre serviços em diferentes clusters GKE usando descoberta automática de endpoints e balanceamento de carga gerenciado pelo Google Cloud.

**⚠️ Importante**: O MCS **não é suportado pelo Terraform** e deve ser habilitado manualmente via `gcloud` após o provisionamento da infraestrutura.

### O que é MCS?

MCS permite que serviços em clusters diferentes se comuniquem como se estivessem no mesmo cluster, usando:
- **ServiceExport**: Marca um Service para exportação multi-cluster
- **ServiceImport**: Criado automaticamente nos clusters remotos
- **DNS Multi-cluster**: Resolução via `*.svc.clusterset.local`
- **Traffic Director**: Balanceamento de carga global entre clusters

### Pré-requisitos

Antes de habilitar o MCS, certifique-se de que:
1. ✅ Os clusters GKE foram provisionados via Terraform
2. ✅ Os clusters estão registrados no **GKE Hub Fleet** (feito automaticamente pelo Terraform)
3. ✅ O **Anthos Service Mesh (ASM)** está habilitado nos clusters
4. ✅ Você tem permissões para gerenciar features do Fleet (`gkehub.features.*`)

### Habilitar MCS

Siga a [documentação oficial do Google Cloud](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services?hl=pt-br) para habilitar o MCS. Abaixo está um resumo dos passos:

#### 1. Obter Membership IDs dos clusters

```bash
PROJECT_ID="infra-474223"

# Listar memberships dos clusters
gcloud container fleet memberships list --project=$PROJECT_ID

# Ou obter via Terraform output (se disponível)
terraform output -json | jq '.anthos_service_mesh_status.value.membership_ids'
```

#### 2. Habilitar a feature MCS

```bash
# Habilitar Multi-cluster Services no Fleet
gcloud container fleet multi-cluster-services enable --project=$PROJECT_ID
```

#### 3. Configurar o Config Cluster

Escolha um cluster para ser o **config cluster** (geralmente o primeiro cluster):

```bash
# Substitua <MEMBERSHIP_ID> pelo ID do membership do cluster escolhido
CONFIG_MEMBERSHIP="projects/$PROJECT_ID/locations/global/memberships/<MEMBERSHIP_ID>"

# Configurar o config_membership
gcloud container fleet multi-cluster-services update \
  --config-membership=$CONFIG_MEMBERSHIP \
  --project=$PROJECT_ID
```

#### 4. Registrar todos os clusters

```bash
# Obter todos os membership IDs (separados por vírgula)
MEMBERSHIPS="projects/$PROJECT_ID/locations/global/memberships/<MEMBERSHIP_1>,projects/$PROJECT_ID/locations/global/memberships/<MEMBERSHIP_2>"

# Registrar todos os clusters no MCS
gcloud container fleet multi-cluster-services update \
  --config-membership=$CONFIG_MEMBERSHIP \
  --memberships=$MEMBERSHIPS \
  --project=$PROJECT_ID
```

#### 5. Verificar status

```bash
# Verificar se o MCS está configurado
gcloud container fleet multi-cluster-services describe --project=$PROJECT_ID

# Verificar memberships registrados
gcloud container fleet memberships list --project=$PROJECT_ID
```

### Usar MCS

Após habilitar o MCS, você pode:

1. **Exportar serviços** usando `ServiceExport` (veja exemplo em `mcs-demo/`)
2. **Acessar serviços remotos** via DNS `service.namespace.svc.clusterset.local`
3. **Testar comunicação** entre clusters usando os scripts em `mcs-demo/scripts/`

### Documentação

- **Demo e Exemplos**: Veja [mcs-demo/README.md](./mcs-demo/README.md) para demonstração completa
- **Arquitetura**: Consulte [mcs-demo/docs/Arquitetura.md](./mcs-demo/docs/Arquitetura.md) para documentação detalhada da arquitetura
- **Referência Oficial**: [Multi-cluster Services Documentation (PT-BR)](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services?hl=pt-br)

### Notas Importantes

- ⚠️ O MCS **não é suportado pelo Terraform** e deve ser habilitado manualmente
- O MCS funciona em conjunto com o **Anthos Service Mesh (ASM)** para comunicação segura entre clusters
- Todos os clusters devem estar registrados no mesmo **GKE Hub Fleet**
- Após habilitar o MCS, pode levar alguns minutos para a propagação completa

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

