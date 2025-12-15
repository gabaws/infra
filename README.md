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

O Terraform pode ser executado via pipeline CI/CD sem necessidade de `gcloud` CLI instalado, pois:
- Todos os recursos são gerenciados via providers do Terraform (google, google-beta)
- Não há dependência de comandos locais (`kubectl`, `helm`, `gcloud`) durante o `terraform apply`

**Nota**: Se você configurar uma pipeline, certifique-se de que:
- As credenciais do GCP estejam configuradas (via Service Account)
- O provider do Terraform tenha as permissões necessárias

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

## 🔗 Anthos Service Mesh (ASM) / Cloud Service Mesh

O projeto provisiona automaticamente:

1. **Registro no Fleet**: Ambos os clusters são registrados automaticamente no GKE Hub Fleet
2. **Anthos Service Mesh (Cloud Service Mesh)**: A feature do ASM é habilitada no Fleet e configurada com gerenciamento automático usando o provider `google-beta`
3. **Feature Membership**: Cada cluster é registrado na feature do ASM para compartilhar a mesma malha de serviços

### Como Funciona

- Os clusters `master-engine` e `app-engine` fazem parte da mesma **malha de serviços (mesh)**
- Comunicação entre clusters é feita através do ASM com mTLS automático
- O gerenciamento é automático (`MANAGEMENT_AUTOMATIC`), então o ASM é instalado e mantido automaticamente pelo Google Cloud
- **Descoberta automática de serviços**: Com clusters na mesma VPC, Fleet e ASM com gerenciamento automático, a descoberta de serviços entre clusters funciona automaticamente

### Configuração Técnica

O módulo `anthos-service-mesh` usa explicitamente o provider `google-beta` para os recursos:
- `google_gke_hub_feature` (feature do Service Mesh)
- `google_gke_hub_feature_membership` (membership dos clusters)

Isso garante que o Cloud Service Mesh seja habilitado corretamente e apareça como configurado no Feature Manager do GCP.

### Verificar Status do ASM

```bash
# Verificar status da feature do ASM
gcloud container hub features describe servicemesh --project=infra-474223 --location=global

# Verificar memberships dos clusters
terraform output anthos_service_mesh_status

# Listar clusters no Fleet
gcloud container fleet memberships list --project=infra-474223

# Verificar feature memberships (deve mostrar MANAGEMENT_AUTOMATIC)
gcloud container hub memberships describe master-engine-membership --project=infra-474223 --location=global
gcloud container hub memberships describe app-engine-membership --project=infra-474223 --location=global
```

### Troubleshooting: Feature não aparece como configurado

Se o Cloud Service Mesh não aparecer como habilitado no Feature Manager:

1. **Verificar se o provider google-beta está configurado**:
   ```bash
   terraform providers
   # Deve mostrar google-beta
   ```

2. **Verificar se os recursos foram criados com o provider correto**:
   ```bash
   terraform state list | grep anthos_service_mesh
   # Deve mostrar recursos com provider google-beta
   ```

3. **Reaplicar o módulo se necessário**:
   ```bash
   terraform apply -target=module.anthos_service_mesh
   ```

4. **Aguardar alguns minutos**: Após aplicar, pode levar 5-10 minutos para o Feature Manager atualizar o status

### Notas Importantes

- ✅ O ASM é provisionado automaticamente via Terraform usando o provider `google-beta`
- ✅ Ambos os clusters compartilham a mesma malha de serviços
- ✅ mTLS é habilitado automaticamente para comunicação segura entre clusters
- ✅ **Descoberta automática de serviços**: Com clusters na mesma VPC, Fleet e ASM com gerenciamento automático, a descoberta de serviços entre clusters funciona automaticamente
- ⚠️ **Provider google-beta obrigatório**: Os recursos do Service Mesh devem usar o provider `google-beta` para funcionar corretamente
- ℹ️ Exemplos de uso e testes estão disponíveis em `app-demo/` (não fazem parte do provisionamento)

## 🧪 Testes e Validação da Arquitetura

Após o provisionamento da infraestrutura, você pode validar que tudo está funcionando corretamente usando os exemplos e scripts de teste disponíveis em `app-demo/`.

### Arquitetura de Testes

A estrutura de testes demonstra a comunicação multi-cluster usando o **Cloud Service Mesh** com descoberta automática:

```
app-demo/
├── README.md                    # Documentação completa dos testes
├── scripts/
│   ├── deploy.sh                # Deploy automatizado das aplicações de teste
│   ├── test-communication.sh    # Teste de comunicação entre clusters
│   └── check-pods.sh            # Verificação de status dos pods
├── app-engine/                  # Aplicação de teste no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── master-engine/               # Aplicação de teste no cluster master-engine
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

### Fluxo de Testes Recomendado

#### 1. Verificar Infraestrutura Provisionada

```bash
# Verificar clusters criados
gcloud container clusters list --project=infra-474223

# Verificar status do ASM
gcloud container hub features describe servicemesh --project=infra-474223 --location=global

# Verificar clusters no Fleet
gcloud container fleet memberships list --project=infra-474223

# Verificar que os clusters estão na mesma VPC
gcloud container clusters describe master-engine --location=us-central1-a --project=infra-474223 --format="value(network)"
gcloud container clusters describe app-engine --location=us-east1-b --project=infra-474223 --format="value(network)"
```

#### 2. Conectar aos Clusters

```bash
# Conectar ao cluster master-engine
gcloud container clusters get-credentials master-engine \
  --location=us-central1-a \
  --project=infra-474223

# Conectar ao cluster app-engine
gcloud container clusters get-credentials app-engine \
  --location=us-east1-b \
  --project=infra-474223
```

#### 3. Deploy das Aplicações de Teste

```bash
cd app-demo

# Deploy automatizado (recomendado)
./scripts/deploy.sh

# Ou deploy manual
cd app-engine
kubectl apply -k . --context=gke_infra-474223_us-east1-b_app-engine

cd ../master-engine
kubectl apply -k . --context=gke_infra-474223_us-central1-a_master-engine
```

#### 4. Validar Comunicação Multi-cluster

```bash
# Teste automatizado de comunicação
./scripts/test-communication.sh

# Ou teste manual
# De app-engine para master-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}' \
  -- curl http://hello-master-engine.mcs-demo.svc.cluster.local

# De master-engine para app-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}' \
  -- curl http://hello-app-engine.mcs-demo.svc.cluster.local
```

### O que os Testes Validam

1. ✅ **Descoberta Automática de Serviços**: Serviços em um cluster são automaticamente descobertos por pods em outro cluster
2. ✅ **Comunicação Cross-cluster**: Pods podem se comunicar usando DNS padrão do Kubernetes (`svc.cluster.local`)
3. ✅ **Injeção Automática do Sidecar**: O Istio sidecar (`istio-proxy`) é injetado automaticamente nos pods
4. ✅ **mTLS Automático**: Comunicação entre clusters é criptografada automaticamente via mTLS
5. ✅ **Roteamento Transparente**: O Cloud Service Mesh roteia automaticamente o tráfego para o cluster correto

### Características da Arquitetura de Testes

- **Simplicidade**: Apenas Deployment e Service Kubernetes padrão (sem ServiceEntry, ServiceExport ou VirtualService)
- **Descoberta Automática**: O Cloud Service Mesh gerencia tudo automaticamente
- **DNS Padrão**: Usa o DNS padrão do Kubernetes (`<service>.<namespace>.svc.cluster.local`)
- **Multi-cluster Transparente**: Aplicações não precisam saber em qual cluster estão rodando

### Documentação Detalhada

Para mais detalhes sobre os testes, consulte: **[app-demo/README.md](./app-demo/README.md)**

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

