# Teste de Comunicação Cross-Cluster no Cloud Service Mesh do GCP

## 📋 Cenário Testado

Este projeto testa a comunicação entre pods em clusters GKE diferentes através do **Cloud Service Mesh (ASM - Anthos Service Mesh)** gerenciado pelo Google.

### Infraestrutura Atual

- **2 Clusters GKE** em regiões diferentes
- **Mesmo Fleet** do GCP
- **VPC Compartilhada** configurada
- **Cloud Service Mesh (ASM)** habilitado e gerenciado pelo Google
- **Multi-cluster Service Mesh**: ❌ **NÃO HABILITADO**

### Clusters

1. **Cluster A**: `gke-dev-dis-app-engine`
   - Contexto: `gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine`
   - Namespace: `dev-dis-test`
   - Aplicação: `dev-dis-test` (servidor HTTP na porta 80)

2. **Cluster B**: `gke-dev-get-app-engine`
   - Contexto: `gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine`
   - Namespace: `dev-get-test`
   - Aplicação: `dev-get-test` (servidor HTTP na porta 5678, exposto na porta 80 do Service)

## 🏗️ Arquitetura

### Cenário Atual (Multi-cluster Mesh NÃO Habilitado)

```
┌─────────────────────────────────────────────────────────────┐
│                    Fleet do GCP                              │
│                                                               │
│  ┌──────────────────────┐      ┌──────────────────────┐     │
│  │  Cluster A           │      │  Cluster B           │     │
│  │  (dev-dis-app)       │      │  (dev-get-app)       │     │
│  │                      │      │                      │     │
│  │  ┌────────────────┐  │      │  ┌────────────────┐  │     │
│  │  │ Pod            │  │      │  │ Pod            │  │     │
│  │  │ dev-dis-test   │  │      │  │ dev-get-test   │  │     │
│  │  │ + istio-proxy   │  │      │  │ + istio-proxy   │  │     │
│  │  └────────────────┘  │      │  └────────────────┘  │     │
│  │         │             │      │         │             │     │
│  │  ┌──────▼──────┐      │      │  ┌──────▼──────┐      │     │
│  │  │ Service     │      │      │  │ Service     │      │     │
│  │  │ dev-dis-test │      │      │  │ dev-get-test │      │     │
│  │  └─────────────┘      │      │  └─────────────┘      │     │
│  │                       │      │                       │     │
│  │  ┌────────────────┐   │      │  ┌────────────────┐   │     │
│  │  │ ServiceEntry   │   │      │  │ ServiceEntry   │   │     │
│  │  │ (dev-get)      │   │      │  │ (dev-dis)      │   │     │
│  │  └────────────────┘   │      │  └────────────────┘   │     │
│  └───────────────────────┘      └───────────────────────┘     │
│         │                              │                        │
│         └──────────┬───────────────────┘                        │
│                    │                                            │
│         ❌ DNS não resolve cross-cluster                        │
│         ⚠️  ServiceEntry com IP estático necessário             │
│         ⚠️  Sem descoberta automática de serviços               │
└─────────────────────────────────────────────────────────────────┘
```

### Cenário Ideal (Multi-cluster Service Mesh Habilitado)

```
┌─────────────────────────────────────────────────────────────┐
│                    Fleet do GCP                              │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │     Istio Control Plane Multi-Cluster               │   │
│  │     (Descoberta automática de serviços)              │   │
│  └──────────────────────────────────────────────────────┘   │
│                    │                    │                     │
│  ┌─────────────────▼──────┐  ┌─────────▼──────────────┐     │
│  │  Cluster A              │  │  Cluster B             │     │
│  │  (dev-dis-app)          │  │  (dev-get-app)         │     │
│  │                         │  │                        │     │
│  │  ┌────────────────┐    │  │  ┌────────────────┐    │     │
│  │  │ Pod            │    │  │  │ Pod            │    │     │
│  │  │ dev-dis-test   │    │  │  │ dev-get-test   │    │     │
│  │  │ + istio-proxy   │    │  │  │ + istio-proxy   │    │     │
│  │  └────────────────┘    │  │  └────────────────┘    │     │
│  │         │               │  │         │               │     │
│  │  ┌──────▼──────┐       │  │  ┌──────▼──────┐       │     │
│  │  │ Service     │       │  │  │ Service     │       │     │
│  │  │ dev-dis-test │       │  │  │ dev-get-test │       │     │
│  │  └─────────────┘       │  │  └─────────────┘       │     │
│  └─────────────────────────┘  └───────────────────────┘     │
│         │                              │                      │
│         └──────────┬───────────────────┘                      │
│                    │                                          │
│         ✅ DNS resolve via Istio Control Plane                │
│         ✅ Descoberta automática de serviços                  │
│         ✅ ServiceEntry não necessário                        │
│         ✅ Load balancing automático                          │
│         ✅ Observabilidade unificada                           │
└───────────────────────────────────────────────────────────────┘
```

## 📁 Estrutura do Projeto

```
teste-mesh/
├── README.md                          # Esta documentação
├── gke-dev-dis-app-engine/           # Manifestos do Cluster A
│   ├── deployment.yaml               # Aplicação principal (netshoot com servidor HTTP + ferramentas)
│   ├── service.yaml
│   ├── namespace.yaml
│   ├── gateway.yaml
│   ├── virtual-service.yaml
│   ├── serviceentry-dev-get.yaml     # ServiceEntry para Cluster B
│   └── kustomization.yaml
├── gke-dev-get-app-engine/           # Manifestos do Cluster B
│   ├── deployment.yaml               # Aplicação principal (netshoot com servidor HTTP + ferramentas)
│   ├── service.yaml
│   ├── namespace.yaml
│   ├── gateway.yaml
│   ├── virtual-service.yaml
│   ├── serviceentry-dev-dis.yaml     # ServiceEntry para Cluster A
│   └── kustomization.yaml
└── arquivos-teste/                    # Arquivos de teste arquivados
    └── test-pod.yaml
```

## 🚀 Deploy

### Aplicar Manifestos nos Clusters

```bash
# Cluster A (dev-dis-app-engine)
cd gke-dev-dis-app-engine
kubectl apply -k . --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Cluster B (dev-get-app-engine)
cd ../gke-dev-get-app-engine
kubectl apply -k . --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Verificar Status dos Pods

```bash
# Cluster A
kubectl get pods -n dev-dis-test --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Cluster B
kubectl get pods -n dev-get-test --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

**Resultado esperado**: Pods com status `Running` e `READY 2/2` (aplicação + sidecar Istio)

**Nota**: Os pods usam a imagem `nicolaka/netshoot:latest` que possui tanto servidor HTTP quanto ferramentas de rede (`curl`, `nslookup`, etc.), eliminando a necessidade de pods de teste separados.

## 🧪 Testes Manuais

### Pré-requisitos

- `kubectl` configurado com acesso a ambos os clusters
- Pods rodando em ambos os clusters

### Teste 1: Verificar DNS (Falha Esperada)

```bash
# Obter pod do Cluster A (tem servidor HTTP + ferramentas de rede)
POD_NAME=$(kubectl get pod -l app=dev-dis-test -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

# Tentar resolver DNS do serviço do Cluster B
kubectl exec -n dev-dis-test $POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- nslookup dev-get-test.dev-get-test.svc.cluster.local
```

**Resultado esperado**: `NXDOMAIN` - DNS não resolve serviços de outros clusters

### Teste 2: Testar Conectividade Direta por IP

```bash
# Obter IP do pod do Cluster B
POD_IP_B=$(kubectl get pod -l app=dev-get-test -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine \
  -o jsonpath='{.items[0].status.podIP}')

# Testar conectividade TCP direta
kubectl exec -n dev-dis-test $POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- curl -v http://${POD_IP_B}:5678/
```

**Resultado esperado**: Conexão TCP estabelecida, mas pode ser resetada pelo Istio (sem ServiceEntry)

### Teste 3: Verificar ServiceEntry

```bash
# Verificar ServiceEntry no Cluster A
kubectl get serviceentry -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Verificar status do ServiceEntry
kubectl get serviceentry dev-get-test-cross-cluster -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o yaml | grep -A 10 "status:"
```

**Resultado esperado**: ServiceEntry criado e aceito, mas DNS ainda não resolve

### Teste 4: Verificar Sidecar do Istio

```bash
# Verificar containers no pod da aplicação
APP_POD=$(kubectl get pod -l app=dev-dis-test -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod $APP_POD -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o jsonpath='{.spec.containers[*].name}'
```

**Resultado esperado**: `dev-dis-test istio-proxy` - Sidecar injetado automaticamente

### Teste 5: Testar Comunicação Cross-Cluster via ServiceEntry

```bash
# Testar comunicação cross-cluster usando o pod principal
kubectl exec -n dev-dis-test $POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- curl -v http://dev-get-test.dev-get-test.svc.cluster.local:80/
```

**Resultado esperado**: Mesmo com ServiceEntry configurado, o DNS ainda não resolve. Isso confirma que é necessário habilitar multi-cluster mesh para comunicação automática.

## ❌ Erros Encontrados

### Erro 1: DNS não resolve serviços cross-cluster

**Comando executado:**
```bash
kubectl exec -n dev-dis-test mesh-test-client \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- curl -v http://dev-get-test.dev-get-test.svc.cluster.local:80/server
```

**Erro:**
```
* Could not resolve host: dev-get-test.dev-get-test.svc.cluster.local
curl: (6) Could not resolve host
```

**Motivo:**
O DNS do Kubernetes não resolve serviços de outros clusters. O ServiceEntry do Istio informa como rotear o tráfego, mas não cria um registro DNS. Para comunicação cross-cluster funcionar automaticamente, é necessário que o **Istio Control Plane Multi-Cluster** esteja habilitado.

### Erro 2: ServiceEntry com MESH_INTERNAL não suportado

**Erro:**
```
ERROR: MESH_INTERNAL is not supported
```

**Solução:**
Alterado para `location: MESH_EXTERNAL` no ServiceEntry.

### Erro 3: Container sem curl/nslookup (RESOLVIDO)

**Erro:**
```
exec: "curl": executable file not found in $PATH
exec: "nslookup": executable file not found in $PATH
```

**Motivo:**
As imagens `hashicorp/http-echo` são muito minimalistas e não possuem ferramentas como `curl` ou `nslookup`. 

**Solução:**
Substituída a imagem `hashicorp/http-echo` por `nicolaka/netshoot:latest` que possui:
- ✅ Servidor HTTP (via Python)
- ✅ Ferramentas de rede (`curl`, `nslookup`, `dig`, `nc`, etc.)
- ✅ Todas as ferramentas necessárias para testes e troubleshooting

Isso elimina a necessidade de pods de teste separados, simplificando a arquitetura.

## 🔍 Motivos dos Problemas

### Por que o DNS não resolve?

1. **DNS do Kubernetes é local ao cluster**: Cada cluster tem seu próprio DNS (`kube-dns` ou `CoreDNS`) que só conhece serviços dentro do próprio cluster.

2. **ServiceEntry não cria DNS**: O ServiceEntry do Istio informa ao control plane como rotear tráfego, mas não cria registros DNS. Ele funciona apenas para tráfego que já está sendo roteado pelo Istio.

3. **Multi-cluster Mesh necessário**: Para comunicação cross-cluster automática, o **Istio Control Plane Multi-Cluster** precisa estar habilitado, permitindo que o Istio faça descoberta automática de serviços através do control plane compartilhado.

### Documentação Oficial do GCP

Segundo a [documentação oficial do Anthos Service Mesh](https://cloud.google.com/service-mesh/docs/overview):

> **Multi-cluster Service Mesh**: Para comunicação cross-cluster, você precisa habilitar o multi-cluster service mesh. Isso permite que o Istio Control Plane faça descoberta automática de serviços em múltiplos clusters e roteie o tráfego entre eles.

**Referências:**
- [Anthos Service Mesh - Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-overview)
- [Configurar Multi-cluster Service Mesh](https://cloud.google.com/service-mesh/docs/multicluster-setup)
- [Istio Multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/)

## ⚖️ Benefícios do ASM com Multi-cluster vs Sem Multi-cluster

### Com Multi-cluster Service Mesh Habilitado ✅

- ✅ **Descoberta automática de serviços**: Serviços em qualquer cluster são automaticamente descobertos
- ✅ **DNS cross-cluster**: Resolução automática de FQDN entre clusters
- ✅ **Load balancing automático**: Distribuição de carga entre pods em múltiplos clusters
- ✅ **Failover automático**: Se um cluster falhar, tráfego é redirecionado automaticamente
- ✅ **Observabilidade unificada**: Métricas, logs e traces de todos os clusters em um único lugar
- ✅ **Gerenciamento centralizado**: Políticas de segurança e roteamento aplicadas globalmente
- ✅ **Sem ServiceEntry manual**: Não é necessário criar ServiceEntry para cada serviço cross-cluster
- ✅ **Service Mesh completo**: Todas as funcionalidades do Istio funcionam entre clusters

### Sem Multi-cluster Service Mesh (Cenário Atual) ⚠️

- ⚠️ **ServiceEntry manual necessário**: Precisa criar ServiceEntry com IPs estáticos para cada serviço
- ⚠️ **DNS não funciona**: Não é possível resolver serviços de outros clusters via DNS
- ⚠️ **Sem descoberta automática**: Mudanças em serviços requerem atualização manual do ServiceEntry
- ⚠️ **Sem load balancing cross-cluster**: Load balancing funciona apenas dentro do cluster
- ⚠️ **Sem failover automático**: Falhas em um cluster não são tratadas automaticamente
- ⚠️ **Observabilidade fragmentada**: Métricas e logs separados por cluster
- ⚠️ **Manutenção manual**: IPs de pods mudam, requerendo atualização constante dos ServiceEntries
- ✅ **Funcionalidades dentro do cluster**: Todas as funcionalidades do Istio funcionam normalmente dentro de cada cluster

## 📊 Comparação de Cenários

| Funcionalidade | Sem Multi-cluster | Com Multi-cluster |
|----------------|-------------------|-------------------|
| DNS Cross-cluster | ❌ Não funciona | ✅ Funciona automaticamente |
| Descoberta de Serviços | ❌ Manual (ServiceEntry) | ✅ Automática |
| Load Balancing | ⚠️ Apenas intra-cluster | ✅ Cross-cluster |
| Failover | ❌ Manual | ✅ Automático |
| Observabilidade | ⚠️ Fragmentada | ✅ Unificada |
| Manutenção | ⚠️ Alta (IPs estáticos) | ✅ Baixa (automática) |
| ServiceEntry | ⚠️ Necessário | ✅ Não necessário |
| Segurança | ✅ Por cluster | ✅ Global |

## 🔧 Como Habilitar Multi-cluster Service Mesh

### Pré-requisitos

1. Clusters no mesmo Fleet do GCP
2. VPC compartilhada ou VPC conectadas
3. ASM habilitado em ambos os clusters
4. Permissões adequadas no GCP

### Comandos

```bash
# Verificar se os clusters estão no mesmo fleet
gcloud container fleet memberships list

# Verificar configuração atual do ASM
gcloud container fleet mesh describe

# Habilitar multi-cluster mesh (exemplo)
gcloud container fleet mesh update \
  --management automatic \
  --memberships CLUSTER_A,CLUSTER_B

# Verificar status
gcloud container fleet mesh describe --format="yaml(multicluster)"
```

**Documentação completa**: [Configurar Multi-cluster Service Mesh](https://cloud.google.com/service-mesh/docs/multicluster-setup)

## 📝 Notas Importantes

1. **ServiceEntry com IP estático**: No cenário atual, os ServiceEntries usam IPs estáticos dos pods. Esses IPs mudam quando pods são recriados, exigindo atualização manual.

2. **Namespace labels**: Ambos os namespaces têm o label `istio.io/rev: asm-managed` para injeção automática do sidecar.

3. **Portas**: 
   - Cluster A: Container escuta na porta 80
   - Cluster B: Container escuta na porta 5678, Service expõe na porta 80

4. **Test-pod.yaml**: Foi arquivado em `arquivos-teste/` pois não é mais necessário - os pods principais já possuem todas as ferramentas de teste.

5. **Imagens utilizadas**:
   - **Aplicações principais**: `nicolaka/netshoot:latest` 
     - Servidor HTTP simples (via Python)
     - Ferramentas de rede completas (`curl`, `nslookup`, `dig`, `nc`, `tcpdump`, etc.)
     - Elimina necessidade de pods de teste separados

## 🔗 Referências

- [Anthos Service Mesh - Documentação Oficial](https://cloud.google.com/service-mesh/docs)
- [Multi-cluster Service Mesh Overview](https://cloud.google.com/service-mesh/docs/multicluster-overview)
- [Istio Multi-cluster Setup](https://istio.io/latest/docs/setup/install/multicluster/)
- [ServiceEntry Documentation](https://istio.io/latest/docs/reference/config/networking/service-entry/)

## 👥 Autores

Teste realizado para validar comunicação cross-cluster no Cloud Service Mesh do GCP.

---

**Última atualização**: 2025-11-18
