# Módulo de Firewall para Cloud Service Mesh Multi-Cluster

Este módulo cria as regras de firewall necessárias para habilitar a descoberta de endpoints entre clusters no Cloud Service Mesh (Anthos Service Mesh).

## Visão Geral

Quando você configura o Cloud Service Mesh com múltiplos clusters GKE, é necessário abrir portas específicas de firewall para permitir a comunicação entre os clusters. Este módulo automatiza a criação dessas regras seguindo as recomendações oficiais da Google.

**Documentação oficial:** [Configurar uma malha de vários clusters no GKE](https://cloud.google.com/service-mesh/docs/operate-and-maintain/multi-cluster?hl=pt-br#create_firewall_rule)

## Arquitetura

### Cenário Suportado

- ✅ Múltiplos clusters GKE em **projetos separados** ou **mesmo projeto**
- ✅ Clusters em uma **VPC compartilhada (Shared VPC)** ou **VPC única**
- ✅ Cada cluster em uma **subnet diferente**
- ✅ Nós privados (`enable_private_nodes = true`)

### Comunicação Permitida

As regras criadas permitem **tráfego bidirecional** entre **todas as subnets** dos clusters:

```
Cluster A (Subnet 10.0.1.0/24) ←→ Cluster B (Subnet 10.0.2.0/24)
```

## Portas Abertas

### TCP (Regra Principal)

| Porta | Componente | Finalidade |
|-------|------------|------------|
| **15012** | Istiod | Distribuição de certificados mTLS entre clusters |
| **15017** | Istiod | Webhook de validação de configuração |
| **443** | Envoy ↔ Envoy | Tráfego mTLS cross-cluster (HTTPS seguro) |
| **10250** | Kubelet | Health checks e liveness probes internode |
| **15010** | Envoy ↔ Envoy | xDS e controle (dependendo da versão) |
| **15011** | Envoy ↔ Envoy | xDS e controle (dependendo da versão) |

### UDP (Regra Secundária)

| Porta | Componente | Finalidade |
|-------|------------|------------|
| **53** | CoreDNS | DNS interno do Kubernetes |
| **8125** | StatsD | Telemetria e métricas |
| **8126** | StatsD | Telemetria e métricas |

### ICMP

Permitido para troubleshooting de conectividade de rede.

## Regras Criadas

O módulo cria **2 regras de firewall**:

1. **`{network_name}-allow-service-mesh-tcp`**
   - Protocolo: TCP + ICMP
   - Origem: Todas as subnets dos clusters
   - Destino: Todos os nodes na rede (filtrado por subnet)

2. **`{network_name}-allow-service-mesh-udp`**
   - Protocolo: UDP
   - Origem: Todas as subnets dos clusters
   - Destino: Todos os nodes na rede (filtrado por subnet)

## Como Funciona

### Origem do Tráfego (source_ranges)

As regras permitem tráfego vindo de **todas as subnets** dos clusters:

```hcl
source_ranges = [
  "10.0.1.0/24",  # Subnet do Cluster A
  "10.0.2.0/24",  # Subnet do Cluster B
  # ... outras subnets
]
```

Isso significa:
- ✅ Cluster A pode se comunicar com Cluster B
- ✅ Cluster B pode se comunicar com Cluster A
- ✅ Cada cluster pode se comunicar consigo mesmo (tráfego interno)

### Destino do Tráfego

Como os clusters estão em subnets diferentes e os nós são privados, o tráfego já é naturalmente filtrado por subnet. Não é necessário usar `target_tags` específicos, pois:

1. O GKE cria automaticamente rotas para cada subnet
2. O firewall do GCP aplica as regras baseado na subnet de destino
3. O tráfego entre subnets já é roteado corretamente pela VPC

## Exemplo de Uso

```hcl
module "firewall" {
  source = "./modules/firewall"

  project_id   = "meu-projeto"
  network_name = "main-vpc"

  subnets = [
    {
      name          = "subnet-us-central1"
      ip_cidr_range = "10.0.1.0/24"
      region        = "us-central1"
    },
    {
      name          = "subnet-us-east1"
      ip_cidr_range = "10.0.2.0/24"
      region        = "us-east1"
    }
  ]

  clusters = {
    master-engine = {
      region = "us-central1"
      zone   = "us-central1-a"
    }
    app-engine = {
      region = "us-east1"
      zone   = "us-east1-b"
    }
  }
}
```

## VPC Compartilhada (Shared VPC)

Se você estiver usando **Shared VPC**:

⚠️ **IMPORTANTE:** As regras de firewall devem ser criadas no **Host Project** da Shared VPC, não nos projetos dos clusters.

O módulo já está preparado para isso - basta executar o Terraform no projeto correto:

```hcl
# No Host Project
module "firewall" {
  source = "./modules/firewall"
  
  project_id   = var.host_project_id  # ← Host Project
  network_name = var.shared_vpc_name
  # ...
}
```

## Segurança

### Princípio do Menor Privilégio

As regras criadas seguem o princípio do menor privilégio:

- ✅ Apenas portas específicas necessárias para o Service Mesh
- ✅ Apenas tráfego entre subnets dos clusters (não de internet)
- ✅ Logs habilitados para auditoria e troubleshooting

### Comparação com Regra Genérica

**❌ NÃO RECOMENDADO** (muito permissivo):
```hcl
# Permite TODAS as portas (0-65535)
source_ranges = ["10.0.0.0/8"]
```

**✅ RECOMENDADO** (este módulo):
```hcl
# Permite APENAS portas necessárias
ports = ["15012", "15017", "443", "10250", "15010", "15011"]
source_ranges = ["10.0.1.0/24", "10.0.2.0/24"]  # Apenas subnets dos clusters
```

## Troubleshooting

### Verificar Regras Criadas

```bash
# Listar regras de firewall
gcloud compute firewall-rules list \
  --project=meu-projeto \
  --filter="name~allow-service-mesh"

# Ver detalhes de uma regra
gcloud compute firewall-rules describe main-vpc-allow-service-mesh-tcp \
  --project=meu-projeto
```

### Verificar Logs de Firewall

```bash
# Ver logs de firewall (requer Cloud Logging habilitado)
gcloud logging read "resource.type=gce_firewall_rule" \
  --project=meu-projeto \
  --limit=50
```

### Testar Conectividade

```bash
# De um pod no Cluster A, testar conectividade com Cluster B
kubectl exec -it <pod-name> -n <namespace> -- \
  nc -zv <ip-do-pod-cluster-b> 443

# Verificar se o Envoy está se comunicando
kubectl logs <pod-name> -c istio-proxy -n <namespace>
```

## Dependências

- ✅ VPC criada e configurada
- ✅ Subnets criadas com CIDRs definidos
- ✅ Clusters GKE criados e registrados no Fleet
- ✅ Cloud Service Mesh habilitado nos clusters

## Referências

- [Documentação oficial: Multi-cluster setup](https://cloud.google.com/service-mesh/docs/operate-and-maintain/multi-cluster?hl=pt-br)
- [Documentação oficial: Firewall rules](https://cloud.google.com/service-mesh/docs/operate-and-maintain/multi-cluster?hl=pt-br#create_firewall_rule)
- [Portas do Istio](https://istio.io/latest/docs/ops/deployment/requirements/#ports-used-by-istio)

