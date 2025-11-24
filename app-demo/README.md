# Demo Cloud Service Mesh - Comunicação Multi-cluster

Demonstração de comunicação entre serviços em diferentes clusters GKE usando **Cloud Service Mesh (Anthos Service Mesh gerenciado)** com descoberta automática de serviços.

## 🎯 Como Funciona

Com o **Cloud Service Mesh** configurado com gerenciamento automático, a descoberta de serviços e endpoints entre clusters funciona **automaticamente** quando:

1. ✅ Clusters na mesma VPC
2. ✅ Clusters na mesma Fleet (GKE Hub)
3. ✅ Anthos Service Mesh habilitado com `MANAGEMENT_AUTOMATIC`

**Não é necessário** configurar ServiceEntry, ServiceExport, VirtualService ou DestinationRule manualmente. O Cloud Service Mesh gerencia tudo automaticamente!

## 📋 Estrutura

```
app-demo/
├── README.md
├── scripts/
│   ├── deploy.sh                    # Script de deploy automatizado
│   ├── test-communication.sh        # Script de teste de comunicação
│   └── check-pods.sh                # Script para verificar pods em ambos clusters
├── app-engine/                      # Aplicação no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── master-engine/                   # Aplicação no cluster master-engine
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## 🚀 Deploy

### Pré-requisitos

1. ✅ Clusters GKE criados na mesma VPC
2. ✅ Clusters registrados no Fleet (GKE Hub)
3. ✅ Anthos Service Mesh habilitado com gerenciamento automático
4. ✅ `kubectl` e `gcloud` configurados

**Nota**: Se você usou o Terraform deste projeto, todos os pré-requisitos já estão configurados!

### Deploy Automatizado

```bash
./scripts/deploy.sh
```

O script irá:
- Conectar aos clusters
- Criar o namespace com label para injeção automática do Istio
- Fazer deploy das aplicações (Deployment + Service)
- Verificar status dos pods
- Executar testes de comunicação

### Deploy Manual

```bash
# Cluster app-engine
cd app-engine
kubectl apply -k . --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
cd ../master-engine
kubectl apply -k . --context=gke_infra-474223_us-central1-a_master-engine
```

## 🧪 Testes

### Teste Automatizado

```bash
./scripts/test-communication.sh
```

O script verifica automaticamente se os pods estão prontos antes de executar os testes de comunicação.

### Teste Manual

```bash
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

## 📝 Formato DNS

Com o Cloud Service Mesh, você usa o **DNS padrão do Kubernetes**:

```
<service-name>.<namespace>.svc.cluster.local
```

Exemplos:
- `hello-app-engine.mcs-demo.svc.cluster.local`
- `hello-master-engine.mcs-demo.svc.cluster.local`

**Nota**: Se estiver no mesmo namespace, pode usar apenas o nome do serviço:
- `hello-app-engine`
- `hello-master-engine`

## ✅ Verificação

### Verificar Pods (deve mostrar 2/2: app + istio-proxy)

```bash
# Verificar pods em ambos os clusters
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine

# Ou usar o script de verificação
./scripts/check-pods.sh
```

### Verificar Serviços

```bash
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar Injeção do Sidecar

```bash
# Verificar containers no pod (deve mostrar: hello-server istio-proxy)
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
```

### Acessar Pods para Debug

```bash
# Especificar o container com -c
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -c hello-server -- /bin/sh

# Para acessar o sidecar istio-proxy (se necessário)
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -c istio-proxy -- /bin/sh
```

## 🔍 Troubleshooting

### Diagnóstico de Pods Pendentes

Se os pods estiverem em estado `Pending`, verifique:

```bash
# Verificar nós disponíveis
kubectl get nodes --context=<contexto>

# Verificar status e eventos dos pods pendentes
kubectl describe pod <pod-name> -n mcs-demo --context=<contexto>

# Verificar recursos disponíveis (CPU/memória)
kubectl top nodes --context=<contexto>

# Verificar taints e tolerations
kubectl describe node <node-name> --context=<contexto> | grep -A 5 Taints

# Verificar requests/limits dos pods
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].resources}'
```

### Verificar Status do Service Mesh

```bash
# Verificar status da feature do ASM
gcloud container hub features describe servicemesh --project=infra-474223 --location=global

# Listar clusters no Fleet
gcloud container fleet memberships list --project=infra-474223

# Verificar se os clusters estão na mesma VPC
gcloud container clusters describe master-engine --location=us-central1-a --project=infra-474223 --format="value(network)"
gcloud container clusters describe app-engine --location=us-east1-b --project=infra-474223 --format="value(network)"
```

### Verificações Rápidas

```bash
# Verificar pods em ambos os clusters
./scripts/check-pods.sh

# Verificar sidecar injection
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
# Deve mostrar: hello-server istio-proxy

# Testar DNS dentro do pod
kubectl exec -n mcs-demo -it <pod-name> --context=<contexto> -c hello-server -- \
  nslookup hello-master-engine.mcs-demo.svc.cluster.local

# Verificar eventos do namespace
kubectl get events -n mcs-demo --context=<contexto> --sort-by='.lastTimestamp'
```

### Problemas Comuns

#### 1. Pods não conseguem se comunicar

**Verificar:**
- ✅ Sidecar Istio está injetado? (`istio-proxy` container presente)
- ✅ Namespace tem label `istio-injection: enabled`?
- ✅ Serviços estão criados em ambos os clusters?
- ✅ Aguardou alguns minutos após criar os serviços? (propagação da descoberta)

#### 2. Sidecar não está sendo injetado

**Solução:**
- Verificar se o namespace tem a label: `istio-injection: enabled`
- Ou adicionar annotation no pod: `sidecar.istio.io/inject: "true"`

#### 3. DNS não resolve

**Verificar:**
- ✅ Serviços estão criados?
- ✅ Pods estão rodando?
- ✅ Aguardou alguns minutos para propagação?

## 📚 Documentação

### Referências Externas

- [Cloud Service Mesh - Descoberta Automática](https://istio.io/v1.27/docs/ops/deployment/deployment-models/#endpoint-discovery-with-multiple-control-planes)
- [Anthos Service Mesh - Provisionamento](https://docs.cloud.google.com/service-mesh/docs/onboarding/provision-control-plane?hl=pt-br)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)

## 🎓 Conceitos Importantes

### Descoberta Automática de Serviços

Com o Cloud Service Mesh gerenciado, o Istio automaticamente:
- Descobre serviços em todos os clusters da mesma Fleet
- Propaga endpoints entre clusters
- Configura roteamento e balanceamento de carga
- Habilita mTLS automaticamente para comunicação segura

### Requisitos para Comunicação Multi-cluster

1. **Mesma VPC**: Clusters devem estar na mesma rede VPC
2. **Mesma Fleet**: Clusters devem estar registrados no mesmo GKE Hub Fleet
3. **ASM Habilitado**: Anthos Service Mesh com gerenciamento automático
4. **Sidecar Injetado**: Pods devem ter o sidecar `istio-proxy` injetado

### DNS e Descoberta

- Use o DNS padrão do Kubernetes: `<service>.<namespace>.svc.cluster.local`
- O Cloud Service Mesh automaticamente roteia para o cluster correto
- Não é necessário configurar ServiceEntry ou ServiceExport
