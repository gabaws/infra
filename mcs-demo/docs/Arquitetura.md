# Arquitetura Multi-cluster Services (MCS) com Anthos Service Mesh

## 📑 Índice

1. [Visão Geral](#visão-geral)
2. [Componentes Principais](#componentes-principais)
3. [Diagrama de Arquitetura](#diagrama-de-arquitetura)
4. [Fluxo de Comunicação](#fluxo-de-comunicação)
5. [Resolução de Nomes DNS](#resolução-de-nomes-dns)
6. [Discovery e Load Balancing](#discovery-e-load-balancing)
7. [Segurança e Isolamento](#segurança-e-isolamento)
8. [Referências](#referências)

---

## Visão Geral

Esta arquitetura implementa comunicação entre serviços distribuídos em múltiplos clusters GKE usando **Multi-cluster Services (MCS)** em conjunto com **Anthos Service Mesh (ASM)**. A solução permite que serviços em diferentes clusters se comuniquem de forma transparente, como se estivessem no mesmo cluster, utilizando descoberta automática de endpoints e balanceamento de carga gerenciado pelo Google Cloud.

### Objetivos

- **Transparência**: Serviços se comunicam usando DNS padrão (`clusterset.local`)
- **Descoberta Automática**: Endpoints são descobertos e sincronizados automaticamente
- **Alta Disponibilidade**: Balanceamento de carga entre clusters e pods
- **Segurança**: Comunicação criptografada via mTLS do Istio
- **Observabilidade**: Telemetria unificada via ASM

---

## Componentes Principais

### 1. Google Cloud Control Plane

#### Traffic Director
- **Função**: Sistema de gerenciamento de tráfego e configuração XDS (eXtensible Discovery Service)
- **Responsabilidades**:
  - Descoberta de endpoints via NEG (Network Endpoint Groups)
  - Distribuição de configuração XDS para proxies Envoy
  - Balanceamento de carga global entre clusters
- **Referência**: [Traffic Director Documentation](https://cloud.google.com/traffic-director/docs)

#### MCS Controller
- **Função**: Controlador Kubernetes que gerencia recursos `ServiceExport` e `ServiceImport`
- **Responsabilidades**:
  - Processar `ServiceExport` de cada cluster
  - Criar `ServiceImport` nos clusters remotos
  - Sincronizar endpoints via NEG
- **Referência**: [Multi-cluster Services](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)

### 2. Cluster A e B (GKE com ASM)

#### Istio Control Plane (istiod)
- **Função**: Plano de controle do service mesh
- **Responsabilidades**:
  - Gerenciar configuração de proxies Envoy (XDS)
  - Implementar políticas de segurança (mTLS, AuthorizationPolicy)
  - Coletar telemetria e métricas
  - Gerenciar roteamento (VirtualService, DestinationRule)
- **Referência**: [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)

#### Envoy Sidecar Proxy
- **Função**: Proxy de dados que intercepta todo tráfego de/para o pod
- **Responsabilidades**:
  - Interceptar tráfego via iptables (redirecionamento transparente)
  - Aplicar políticas de segurança (mTLS)
  - Balanceamento de carga local e multi-cluster
  - Coleta de métricas e traces
- **Referência**: [Envoy Proxy](https://www.envoyproxy.io/docs)

#### Kubernetes Service (ClusterIP)
- **Função**: Abstração de rede que expõe pods como serviço estável
- **Características**:
  - Resolvido apenas dentro do cluster (`cluster.local`)
  - Endpoints gerenciados pelo Endpoints Controller
  - Integração com CoreDNS/kube-dns
- **Referência**: [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)

#### ServiceExport
- **Função**: Recurso customizado que marca um Service para exportação multi-cluster
- **Comportamento**:
  - Cria NEG automaticamente no Google Cloud
  - Sincroniza endpoints com Traffic Director
  - Dispara criação de `ServiceImport` nos clusters remotos
- **Referência**: [ServiceExport API](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#serviceexport)

#### ServiceImport (gke-mcs-*)
- **Função**: Recurso criado automaticamente pelo MCS Controller representando serviço remoto
- **Características**:
  - Criado automaticamente quando `ServiceExport` é detectado
  - Expõe serviço remoto como `gke-mcs-<service-name>`
  - Endpoints sincronizados via NEG
- **Referência**: [ServiceImport](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#serviceimport)

#### CoreDNS / kube-dns
- **Função**: Servidor DNS do cluster
- **Responsabilidades**:
  - Resolver `*.svc.cluster.local` (serviços locais)
  - Resolver `*.svc.clusterset.local` (serviços multi-cluster via MCS)
  - Integração com MCS para descoberta de serviços remotos
- **Referência**: [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

#### Network Endpoint Groups (NEG)
- **Função**: Agrupamento de endpoints de rede no Google Cloud
- **Responsabilidades**:
  - Representar endpoints de pods em formato consumível pelo Traffic Director
  - Sincronização automática quando pods são criados/removidos
  - Integração com balanceamento de carga global
- **Referência**: [Network Endpoint Groups](https://cloud.google.com/load-balancing/docs/negs)

---

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD — CONTROL PLANE                             │
│                                                                             │
│  ┌──────────────────────────────┐    ┌─────────────────────────────────┐    │
│  │      Traffic Director        │◄──►│      MCS Controller             │    │
│  │  (XDS Config / Load Balancer)│    │  (ServiceExport/Import Manager) │    │
│  └──────────────────────────────┘    └─────────────────────────────────┘    │
│           ▲                                    ▲                            │
│           │                                    │                            │
│           │ NEG Sync                           │ ServiceExport Events       │
│           │                                    │                            │
└───────────┼────────────────────────────────────┼────────────────────────────┘
            │                                    │
            │                                    │
    ┌───────┴────────┐                   ┌───────┴────────┐
    │  ServiceExport │                   │  ServiceExport │
    │  (Cluster A)   │                   │  (Cluster B)   │
    └───────┬────────┘                   └───────┬────────┘
            │                                    │
            ▼                                    ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLUSTER A (GKE + ASM)                                │
│                                                                             │
│  ┌──────────────┐                                                           │
│  │   Pod A1     │──┐                                                        │
│  │  (app v1)    │  │                                                        │
│  └──────────────┘  │                                                        │
│                    │                                                        │
│  ┌──────────────┐  │    ┌──────────────────┐                                │
│  │   Pod A2     │──┼───►│ Envoy Sidecar    │                                │
│  │  (app v1)    │  │    │ (istio-proxy)    │                                │
│  └──────────────┘  │    └──────────────────┘                                │
│                    │              │                                         │
│                    │              │ XDS Config                              │ 
│                    │              ▼                                         │
│                    │    ┌──────────────────┐                                │
│                    │    │   istiod         │                                │
│                    │    │ (Control Plane)  │                                │
│                    │    └──────────────────┘                                │
│                    │              │                                         │
│                    └──────────────┼────────────────────────┐                │
│                                   │                        │                │
│                                   ▼                        ▼                │
│                    ┌──────────────────────────────┐                         │
│                    │  Service A (ClusterIP)       │                         │
│                    │  hello-app-engine            │                         │
│                    └──────────────────────────────┘                         │
│                                   │                                         │
│                                   │ DNS Query                               │
│                                   ▼                                         │
│                    ┌──────────────────────────────┐                         │
│                    │  CoreDNS / kube-dns          │                         │
│                    │  *.svc.cluster.local         │                         │
│                    │  *.svc.clusterset.local      │                         │
│                    └──────────────────────────────┘                         │
│                                   │                                         │
│                                   │ ServiceImport (gke-mcs-*)               │
│                                   ▼                                         │
│                    ┌──────────────────────────────┐                         │
│                    │  MCS Endpoints (NEG)         │───► Traffic Director    │
│                    │  (Sincronizado com GCP)      │    (Global LB)          │
│                    └──────────────────────────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ mTLS + Load Balancing
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLUSTER B (GKE + ASM)                                │
│                                                                             │
│  ┌──────────────┐                                                           │
│  │   Pod B1     │──┐                                                        │
│  │  (app v2)    │  │                                                        │
│  └──────────────┘  │                                                        │
│                    │                                                        │
│  ┌──────────────┐  │    ┌──────────────────┐                                │
│  │   Pod B2     │──┼───►│ Envoy Sidecar    │                                │
│  │  (app v2)    │  │    │ (istio-proxy)    │                                │
│  └──────────────┘  │    └──────────────────┘                                │
│                    │              │                                         │
│                    │              │ XDS Config                              │
│                    │              ▼                                         │
│                    │    ┌──────────────────┐                                │
│                    │    │   istiod         │                                │
│                    │    │ (Control Plane)  │                                │
│                    │    └──────────────────┘                                │
│                    │              │                                         │
│                    └──────────────┼────────────────────────┐                │
│                                   │                        │                │
│                                   ▼                        ▼                │
│                    ┌──────────────────────────────┐                         │
│                    │  Service B (ClusterIP)       │                         │
│                    │  hello-master-engine         │                         │
│                    └──────────────────────────────┘                         │
│                                   │                                         │
│                                   │ DNS Query                               │
│                                   ▼                                         │
│                    ┌──────────────────────────────┐                         │
│                    │  CoreDNS / kube-dns          │                         │
│                    │  *.svc.cluster.local         │                         │
│                    │  *.svc.clusterset.local      │                         │
│                    └──────────────────────────────┘                         │
│                                   │                                         │
│                                   │ ServiceImport (gke-mcs-*)               │
│                                   ▼                                         │
│                    ┌──────────────────────────────┐                         │
│                    │  MCS Endpoints (NEG)         │───► Traffic Director    │
│                    │  (Sincronizado com GCP)      │    (Global LB)          │
│                    └──────────────────────────────┘                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Fluxo de Comunicação

### Cenário: Pod A1 (Cluster A) → Pod B1 (Cluster B)

1. **Requisição Inicial**
   - Pod A1 faz requisição HTTP para `hello-master-engine.mcs-demo.svc.clusterset.local`
   - Requisição é interceptada pelo Envoy sidecar via iptables (redirecionamento transparente)

2. **Resolução DNS**
   - Envoy sidecar consulta CoreDNS
   - CoreDNS resolve `*.svc.clusterset.local` via integração MCS
   - Retorna endpoints do `ServiceImport` (gke-mcs-hello-master-engine)

3. **Descoberta de Endpoints**
   - Envoy recebe configuração XDS do istiod
   - istiod consulta endpoints do `ServiceImport` que são sincronizados via NEG
   - Traffic Director fornece lista de endpoints válidos do Cluster B

4. **Roteamento e Balanceamento**
   - Envoy aplica políticas de roteamento (VirtualService, DestinationRule)
   - Seleciona endpoint no Cluster B usando algoritmo de load balancing configurado
   - Estabelece conexão mTLS com Envoy sidecar do Pod B1

5. **Comunicação Segura**
   - Tráfego é criptografado via mTLS entre sidecars
   - Envoy do Pod B1 faz forward para container da aplicação
   - Resposta segue o caminho inverso

### Componentes Envolvidos

- **Envoy Sidecar**: Interceptação, roteamento, mTLS
- **istiod**: Configuração XDS, descoberta de serviços
- **CoreDNS**: Resolução DNS multi-cluster
- **MCS Controller**: Sincronização de ServiceExport/Import
- **Traffic Director**: Descoberta global de endpoints via NEG
- **NEG**: Representação de endpoints no Google Cloud

---

## Resolução de Nomes DNS

### Domínios Suportados

#### `*.svc.cluster.local` (Local)
- **Escopo**: Apenas dentro do cluster
- **Resolução**: CoreDNS consulta Services locais
- **Uso**: Comunicação intra-cluster

#### `*.svc.clusterset.local` (Multi-cluster)
- **Escopo**: Todos os clusters no Fleet
- **Resolução**: CoreDNS consulta ServiceImport via MCS
- **Uso**: Comunicação inter-cluster
- **Formato**: `<service-name>.<namespace>.svc.clusterset.local`

### Exemplo Prático

```bash
# Serviço local (Cluster A)
hello-app-engine.mcs-demo.svc.cluster.local

# Serviço remoto (Cluster B, via MCS)
hello-master-engine.mcs-demo.svc.clusterset.local
```

### Mecanismo de Resolução

1. **Query DNS**: Aplicação consulta `hello-master-engine.mcs-demo.svc.clusterset.local`
2. **CoreDNS**: Identifica domínio `clusterset.local` e consulta MCS Controller
3. **ServiceImport**: MCS Controller retorna endpoints do `gke-mcs-hello-master-engine`
4. **Resposta**: CoreDNS retorna lista de IPs dos endpoints (via NEG)
5. **Envoy**: Recebe configuração XDS com endpoints atualizados do istiod

**Referência**: [Kubernetes DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

## Discovery e Load Balancing

### Descoberta de Endpoints

#### NEG (Network Endpoint Groups)
- **Criação Automática**: Quando `ServiceExport` é criado, MCS Controller cria NEG automaticamente
- **Sincronização**: Endpoints são sincronizados em tempo real quando pods são criados/removidos
- **Formato**: Cada endpoint contém IP do pod e porta do serviço

#### ServiceImport
- **Criação Automática**: MCS Controller cria `ServiceImport` em todos os clusters do Fleet
- **Endpoints**: Endpoints são populados automaticamente via NEG
- **Atualização**: Endpoints são atualizados automaticamente quando há mudanças

### Balanceamento de Carga

#### Níveis de Balanceamento

1. **Global (Inter-cluster)**
   - Traffic Director distribui requisições entre clusters
   - Baseado em saúde dos endpoints e políticas configuradas

2. **Local (Intra-cluster)**
   - Envoy sidecar distribui requisições entre pods do mesmo cluster
   - Algoritmos: ROUND_ROBIN, LEAST_CONN, RANDOM (configurável via DestinationRule)

3. **Zone-aware**
   - Preferência por endpoints na mesma zona quando possível
   - Reduz latência e custos de rede

#### Configuração via DestinationRule

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: hello-master-engine
spec:
  host: hello-master-engine.mcs-demo.svc.clusterset.local
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
    localityLbSetting:
      enabled: true
```

**Referência**: [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)

---

## Segurança e Isolamento

### mTLS (Mutual TLS)

- **Habilitação**: Automática quando ASM está habilitado
- **Escopo**: Todas as comunicações entre sidecars Envoy
- **Certificados**: Gerenciados automaticamente pelo istiod (Citadel)
- **Renovação**: Automática e transparente

**Referência**: [Istio Security - mTLS](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication)

### Authorization Policies

- **Controle de Acesso**: Políticas granulares por namespace, serviço ou pod
- **RBAC**: Integração com Kubernetes RBAC
- **Exemplo**: Permitir acesso apenas de namespaces específicos

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-mcs-demo
spec:
  selector:
    matchLabels:
      app: hello-master-engine
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["mcs-demo"]
```

**Referência**: [Istio Authorization](https://istio.io/latest/docs/concepts/security/#authorization)

### Network Policies

- **Isolamento**: Kubernetes NetworkPolicies podem ser combinadas com ASM
- **Camadas**: NetworkPolicy (L3/L4) + AuthorizationPolicy (L7)

---

## Referências

### Documentação Oficial

#### Kubernetes
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

#### Istio / Anthos Service Mesh
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)

#### Google Cloud
- [Multi-cluster Services (MCS)](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [Traffic Director](https://cloud.google.com/traffic-director/docs)
- [Network Endpoint Groups (NEG)](https://cloud.google.com/load-balancing/docs/negs)
- [GKE Fleet](https://cloud.google.com/kubernetes-engine/docs/fleets-overview)

### Recursos Adicionais

- [ServiceExport API Reference](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#serviceexport)
- [ServiceImport API Reference](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#serviceimport)
- [XDS Protocol](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)
- [Istio Multi-cluster Deployment](https://istio.io/latest/docs/setup/install/multicluster/)

---

## Glossário

- **ASM**: Anthos Service Mesh, implementação gerenciada do Istio no Google Cloud
- **Envoy**: Proxy de dados usado como sidecar no service mesh
- **istiod**: Control plane do Istio (anteriormente Pilot, Citadel, Galley)
- **MCS**: Multi-cluster Services, feature do GKE para descoberta de serviços entre clusters
- **mTLS**: Mutual TLS, autenticação mútua entre serviços
- **NEG**: Network Endpoint Group, agrupamento de endpoints no Google Cloud
- **ServiceExport**: Recurso Kubernetes que marca um Service para exportação multi-cluster
- **ServiceImport**: Recurso Kubernetes criado automaticamente representando serviço remoto
- **XDS**: eXtensible Discovery Service, protocolo usado pelo Envoy para receber configuração
