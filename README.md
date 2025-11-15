# Infraestrutura GCP - GKE com Anthos Service Mesh

Este projeto provisiona uma infraestrutura escalável no Google Cloud Platform (GCP) utilizando Terraform, seguindo as melhores práticas. A infraestrutura inclui:

- **Projeto GCP** criado usando [terraform-google-project-factory](https://github.com/terraform-google-modules/terraform-google-project-factory)
- **VPC** com subnets privadas e configuração de Cloud NAT
- **2 Clusters GKE** em zonas diferentes para alta disponibilidade
- **Anthos Service Mesh** configurado para comunicação entre pods em clusters separados

## 🏛️ Arquitetura do Ambiente

### Visão Geral

- **Governança**: projeto GCP dedicado criado via Project Factory, com APIs essenciais habilitadas e serviço de billing associado.
- **Rede**: VPC customizada com sub-redes privadas replicadas em múltiplas regiões, Cloud NAT para saída controlada e regras de firewall opinadas.
- **Cômputo Kubernetes**: dois clusters GKE privados distribuídos entre `us-central1-a` e `us-east1-b`, com Workload Identity, Auto-scaling, Network Policy e Binary Authorization.
- **Malha de Serviço**: Anthos Service Mesh interligando os clusters e registrando-os no GKE Hub para tráfego seguro entre workloads.
- **Observabilidade**: integrações nativas com Logging, Monitoring e Prometheus gerenciado.

```mermaid
flowchart TD
    subgraph Projeto["Projeto GCP (Project Factory)"]
        direction TB
        VPC["VPC customizada<br/>Rotas regionais"]
        subgraph Subnets["Sub-redes privadas"]
            S1["Subnet us-central1"]
            S2["Subnet us-east1"]
        end
        VPC --> S1
        VPC --> S2
        NAT["Cloud NAT"]
        VPC --> NAT
    end

    subgraph Cluster1["Cluster GKE 1<br/>us-central1-a"]
        N1["N&oacute;s privados<br/>Workload Identity"]
    end

    subgraph Cluster2["Cluster GKE 2<br/>us-east1-b"]
        N2["N&oacute;s privados<br/>Workload Identity"]
    end

    ASM["Anthos Service Mesh<br/>(GKE Hub + mTLS)"]
    Observabilidade["Logging / Monitoring / Prometheus"]

    S1 --> Cluster1
    S2 --> Cluster2
    Cluster1 --> ASM
    Cluster2 --> ASM
    ASM --> Observabilidade
```

> A versão editável deste diagrama está disponível em `docs/architecture-diagram.mmd`.

### Componentes Principais

#### Projeto e Estado

- **Provisionamento**: criação do projeto com políticas organizacionais herdadas e APIs ativadas automaticamente.
- **Backend do Terraform**: suporta remote state em bucket GCS dedicado, garantindo controle de concorrência via Terraform Cloud Storage.

#### Rede (VPC)

- **Network**: VPC customizada com roteamento regional.
- **Subnets**: sub-redes privadas com ranges secundários para pods e serviços.
- **Cloud NAT**: garante acesso controlado à internet para nós privados.
- **Firewall Rules**: opinadas para comunicação interna, monitoramento e (opcionalmente) acesso administrativo.

#### Clusters GKE

- **Distribuição**: dois clusters privados em zonas diferentes (HA regional).
- **Workload Identity**: integração com IAM para fornecer identidades gerenciadas.
- **Auto-scaling**: definição de limites de nós por pool, com escalonamento automático habilitado.
- **Network Policy**: isolamento de tráfego L3/L4 entre pods.
- **Logging e Monitoring**: envio nativo para serviços de observabilidade do GCP e suporte a Prometheus gerenciado.

#### Anthos Service Mesh

- **GKE Hub**: registros centralizados dos clusters.
- **Service Mesh**: configuração automática do plano de controle com certificados mTLS rotacionados.
- **Multi-cluster**: roteamento seguro entre pods em clusters distintos com políticas unificadas.
- **Plano de dados automatizado**: instalação do Istio (charts oficiais) em cada cluster com revision `asm-managed`.
- **Gateway & GitOps**: provisionamento do Ingress Gateway e do ArgoCD via Helm, com opções de customização em `terraform.tfvars`.

#### Segurança Complementar

- **Binary Authorization**: políticas para garantir que apenas imagens confiáveis sejam executadas.
- **Service Accounts**: reforço para workloads com contas dedicadas e escopos mínimos.
- **Master Authorized Networks**: suporte para restringir o endpoint do plano de controle, incluindo acesso privado opcional.

### Diagrama de Componentes (Caixinhas)

```mermaid
flowchart LR
    classDef module fill:#f3f4ff,stroke:#4f46e5,stroke-width:1px,color:#111827;
    classDef infra fill:#ecfeff,stroke:#0e7490,stroke-width:1px,color:#0f172a;
    classDef service fill:#fff7ed,stroke:#c2410c,stroke-width:1px,color:#1f2937;
    classDef observ fill:#fef3c7,stroke:#d97706,stroke-width:1px,color:#78350f;

    A["Project Factory<br/>(M&oacute;dulo Terraform)"]:::module --> B["Projeto GCP<br/>Billing + APIs"]:::infra
    B --> C["VPC Custom<br/>Subnets privadas"]:::infra
    C --> D1["Cloud NAT"]:::infra
    C --> D2["Firewall Rules"]:::infra
    C --> E1["Cluster GKE 1<br/>us-central1-a"]:::service
    C --> E2["Cluster GKE 2<br/>us-east1-b"]:::service
    E1 --> F["Anthos Service Mesh<br/>Plano de controle"]:::service
    E2 --> F
    F --> G["Observabilidade<br/>Logging / Monitoring / Prometheus"]:::observ
```

> A versão editável deste diagrama está disponível em `docs/architecture-components.mmd`.

## 📋 Pré-requisitos

### Software Necessário

- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) >= 269.0.0
- [jq](https://stedolan.github.io/jq/download/) >= 1.6 (para scripts auxiliares)

### Permissões Necessárias

Para executar este módulo, você precisa de uma Service Account com as seguintes permissões:

- `roles/resourcemanager.folderViewer` na pasta onde o projeto será criado
- `roles/resourcemanager.organizationViewer` na organização
- `roles/resourcemanager.projectCreator` na organização
- `roles/billing.user` na organização
- `roles/storage.admin` no projeto bucket (se aplicável)

### APIs Necessárias

As seguintes APIs serão habilitadas automaticamente no projeto:

- Cloud Resource Manager API
- Cloud Billing API
- Identity and Access Management API
- Compute Engine API
- Kubernetes Engine API
- GKE Hub API
- Anthos Service Mesh API
- Service Networking API
- Logging API
- Monitoring API

## 🚀 Início Rápido

### 0. Configurar Backend Remoto (Opcional mas Recomendado)

Antes de começar, configure o bucket para armazenar o estado do Terraform:

```bash
cd bootstrap/
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas informações
terraform init
terraform apply
```

Depois, configure o backend em `versions.tf` (descomente as linhas do backend) e execute:
```bash
terraform init -migrate-state
```

📖 **Leia mais**: [Documentação completa sobre Backend e Estado](docs/BACKEND_AND_STATE.md)

### 1. Configurar Credenciais do GCP

```bash
# Autenticar no GCP
gcloud auth application-default login

# Ou configurar via variável de ambiente
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"
```

### 2. Configurar Variáveis

Copie o arquivo de exemplo e ajuste conforme necessário:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` com suas informações:

```hcl
project_id             = "infra-474223"
region                 = "us-central1"
primary_cluster_name   = "master-engine"
secondary_cluster_name = "app-engine"
argocd_target_cluster  = "master-engine"
```

### 3. Inicializar Terraform

```bash
terraform init
```

### 4. Planejar e Aplicar

```bash
# Ver o plano de execução
terraform plan

# Aplicar as mudanças
terraform apply
```

> 💡 **Primeiro deploy?**  
> Recursos que dependem de acesso direto ao cluster Kubernetes (Istio/ASM, ArgoCD, gateways) só podem ser instalados depois que os clusters GKE estiverem disponíveis.  
> Execute em duas etapas:
>
> ```bash
> # Cria rede, clusters e mesh
> terraform apply -var enable_cluster_addons=false
>
> # Depois instala os add-ons (Istio, ArgoCD, etc.)
> terraform apply -var enable_cluster_addons=true
> ```
>
> Em execuções subsequentes, um único `terraform apply` já consegue detectar os clusters existentes e criar/atualizar os add-ons normalmente.

### Automação via GitHub Actions

O workflow `Terraform Deploy GKE` já implementa essa estratégia em dois estágios:

- **`terraform-apply-bootstrap`** é executado somente quando o estado remoto ainda não possui os clusters GKE. Ele roda `terraform plan/apply` com `enable_cluster_addons=false` para criar toda a base (VPC, GKE e ASM) sem tentar acessar o Kubernetes.
- **`terraform-apply-addons`** depende do bootstrap, aguarda os clusters ficarem disponíveis e então roda `terraform plan/apply` com `enable_cluster_addons=true`, aplicando Istio, gateways e ArgoCD.

O job de **plan** detecta automaticamente se os clusters já existem e ajusta a variável `enable_cluster_addons`, evitando planos inconsistentes. Assim, em qualquer push para `main` (ou execução manual `workflow_dispatch`), a pipeline provisiona a infraestrutura e depois instala os add-ons sem precisar de intervenções manuais ou execuções repetidas.

## 📁 Estrutura do Projeto

```
.
├── main.tf                          # Configuração principal do Terraform
├── variables.tf                     # Variáveis do módulo raiz
├── outputs.tf                      # Outputs do módulo raiz
├── terraform.tfvars.example        # Exemplo de variáveis
├── README.md                       # Este arquivo
├── .gitignore                      # Arquivos ignorados pelo Git
└── modules/
    ├── vpc/                        # Módulo de VPC
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── gke/                        # Módulo de GKE
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── cluster-addons/             # Add-ons (Istio, Gateway, ArgoCD)
    │   ├── main.tf
    │   └── variables.tf
    └── anthos-service-mesh/        # Módulo de Anthos Service Mesh
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 🔧 Configuração Avançada

### Personalizar Clusters GKE

Edite a variável `gke_clusters` em `terraform.tfvars`:

```hcl
gke_clusters = {
  master-engine = {
    region                = "us-central1"
    zone                  = "us-central1-a"
    initial_node_count    = 2
    min_node_count        = 1
    max_node_count        = 10
    machine_type          = "e2-standard-4"
    disk_size_gb          = 100
    enable_private_nodes  = true
    enable_private_endpoint = false
  }
  app-engine = {
    region                = "us-east1"
    zone                  = "us-east1-b"
    initial_node_count    = 2
    min_node_count        = 1
    max_node_count        = 10
    machine_type          = "e2-standard-4"
    disk_size_gb          = 100
    enable_private_nodes  = true
    enable_private_endpoint = false
  }
}
```

> ⚙️ Use as variáveis `primary_cluster_name`, `secondary_cluster_name` e `argocd_target_cluster`
> para indicar qual cluster é o “master” (recebe o ArgoCD) e qual ficará responsável
> apenas por workloads. Por padrão `master-engine` hospeda o ArgoCD e `app-engine`
> participa da mesma malha, mas sem ArgoCD.

### Configurar Master Authorized Networks

Para acessar o endpoint privado do cluster:

```hcl
master_authorized_networks = [
  {
    cidr_block   = "10.0.0.0/8"
    display_name = "Internal Network"
  }
]
```

### Personalizar Subnets

Ajuste as subnets e ranges secundários:

```hcl
subnets = [
  {
    name          = "subnet-custom"
    ip_cidr_range = "10.0.10.0/24"
    region        = "us-west1"
    description   = "Custom subnet"
  }
]

secondary_ranges = {
  "subnet-custom" = [
    {
      range_name    = "pods"
      ip_cidr_range = "10.10.0.0/16"
    },
    {
      range_name    = "services"
      ip_cidr_range = "10.20.0.0/20"
    }
  ]
}
```

### Reutilizar uma VPC existente

Caso a rede já exista no projeto (por exemplo, ambientes compartilhados), defina `manage_network = false` em `terraform.tfvars`. O módulo deixará de criar a VPC e reutilizará a rede chamada em `network_name`, mantendo a criação das subnets e dos demais recursos associados.

### Automatização do ASM Gateway e ArgoCD

- `istio_chart_version`, `asm_revision`, `istiod_values` e `istio_gateway_values` controlam a instalação do Istio (base, istiod e ingress gateway) via Helm em todos os clusters.
- `install_gateway`, `gateway_namespace` e `gateway_labels` permitem habilitar/desabilitar o gateway e customizar namespace/labels.
- `install_argocd`, `argocd_chart_version`, `argocd_values` definem a instalação do ArgoCD. Use `argocd_target_cluster` para apontar qual cluster recebe o Argo (por padrão, `master-engine`).
- `manage_istio_namespace` controla se o Terraform deve criar/atualizar o namespace `istio-system`. Defina como `false` quando o namespace já é provisionado automaticamente pelo Anthos Service Mesh, evitando erros de “resource already exists” nos pipelines.
- Para adicionar novos clusters é necessário criar provedores `kubernetes`/`helm` com aliases adicionais em `main.tf` e instanciar o módulo `cluster-addons` correspondente.

## 📊 Outputs

Após o deploy, você pode acessar os seguintes outputs:

```bash
# ID do projeto criado
terraform output project_id

# Informações dos clusters
terraform output gke_clusters

# Status do Service Mesh
terraform output anthos_service_mesh_status
```

## 🔐 Segurança

### Boas Práticas Implementadas

- ✅ Nós privados do GKE (sem IPs públicos)
- ✅ Network Policy habilitada
- ✅ Workload Identity para autenticação
- ✅ Service Account padrão desabilitada
- ✅ Logging e monitoring habilitados
- ✅ Binary Authorization configurado

### Recomendações Adicionais

1. **Habilitar Private Endpoint**: Configure `enable_private_endpoint = true` para clusters críticos
2. **Master Authorized Networks**: Restrinja o acesso ao endpoint do master
3. **Service Account Custom**: Use service accounts específicas para cada workload
4. **Secrets Management**: Use Secret Manager ou external-secrets para credenciais
5. **Pod Security Standards**: Configure Pod Security Standards nos namespaces

## 🧪 Testando a Comunicação entre Clusters

Após o deploy, você pode testar a comunicação entre clusters usando o Service Mesh:

```bash
# Conectar ao cluster master (master-engine)
gcloud container clusters get-credentials master-engine --zone us-central1-a --project $(terraform output -raw project_id)

# Conectar ao cluster de aplicações (app-engine)
gcloud container clusters get-credentials app-engine --zone us-east1-b --project $(terraform output -raw project_id)

# Verificar o Service Mesh
kubectl get servicemesh -A
```

## 🧹 Limpeza

Para destruir toda a infraestrutura:

```bash
terraform destroy
```

**⚠️ Atenção**: Isso irá deletar todos os recursos, incluindo o projeto GCP (se configurado).

## 📚 Recursos Adicionais

- [Terraform Google Project Factory](https://github.com/terraform-google-modules/terraform-google-project-factory)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Anthos Service Mesh Documentation](https://cloud.google.com/service-mesh/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## 🤝 Contribuindo

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença Apache 2.0. Veja o arquivo `LICENSE` para mais detalhes.

## 🆘 Troubleshooting

### Erro: "API not enabled"

Certifique-se de que todas as APIs necessárias estão habilitadas. O módulo project-factory deve habilitá-las automaticamente.

### Erro: "Insufficient permissions"

Verifique se a Service Account tem todas as permissões necessárias listadas na seção de Pré-requisitos.

### Clusters não conseguem se comunicar via Service Mesh

1. Verifique se o Anthos Service Mesh está habilitado: `gcloud container hub mesh describe`
2. Verifique os membros do mesh: `gcloud container hub memberships list`
3. Verifique os logs: `kubectl logs -n istio-system`

## 📧 Suporte

Para questões e suporte, abra uma issue no repositório.
