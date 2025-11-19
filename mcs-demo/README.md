# Demo Multi-cluster Services (MCS)

Demonstração de comunicação entre serviços em diferentes clusters GKE usando Multi-cluster Services.

## 📋 Estrutura

```
mcs-demo/
├── README.md
├── scripts/
│   ├── deploy.sh                    # Script de deploy automatizado
│   ├── test-communication.sh        # Script de teste de comunicação
│   ├── diagnose-pending-pods.sh    # Script de diagnóstico de pods pendentes
│   ├── check-metrics.sh            # Script para verificar métricas
│   └── check-telemetry.sh          # Script para verificar telemetria
├── app-engine/                      # Aplicação no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── service-export.yaml
│   └── kustomization.yaml
└── master-engine/                   # Aplicação no cluster master-engine
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── service-export.yaml
    └── kustomization.yaml
```

## 🚀 Deploy

### Pré-requisitos

1. Multi-cluster Services habilitado no Fleet
2. Clusters registrados no Fleet
3. ASM (Anthos Service Mesh) habilitado
4. `kubectl` e `gcloud` configurados

### Deploy Automatizado

```bash
./scripts/deploy.sh
```

O script irá:
- Conectar aos clusters
- Fazer deploy das aplicações
- Verificar status dos pods e ServiceExports
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

### Teste com MCS (Recomendado)

Teste de comunicação usando Multi-cluster Services (MCS):

```bash
./scripts/test-communication.sh
```

O script verifica automaticamente se os pods estão prontos antes de executar os testes de comunicação.

### Teste sem MCS (ASM-only)

Teste de comunicação usando apenas ASM Multi-cluster (ServiceEntry + VirtualService), **sem MCS**:

```bash
# 1. Configurar ServiceEntry e VirtualService
./scripts/setup-asm-multicluster-only.sh

# 2. Testar comunicação
./scripts/test-asm-multicluster-only.sh
```

**Diferenças:**
- **Com MCS**: Usa `service.namespace.svc.clusterset.local` (automático)
- **Sem MCS**: Usa `service-remote.namespace.svc.cluster.local` (manual)

Veja [docs/TESTE_ASM_SEM_MCS.md](./docs/TESTE_ASM_SEM_MCS.md) para mais detalhes.

### Teste Manual

```bash
# De app-engine para master-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}' \
  -- curl http://hello-master-engine.mcs-demo.svc.clusterset.local

# De master-engine para app-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}' \
  -- curl http://hello-app-engine.mcs-demo.svc.clusterset.local
```

## ✅ Verificação

### Verificar Pods (deve mostrar 2/2: app + istio-proxy)

```bash
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar ServiceExports

```bash
kubectl get serviceexport -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get serviceexport -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar Serviços Importados (gke-mcs-*)

```bash
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine | grep gke-mcs
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine | grep gke-mcs
```

## 📝 Formato DNS Multi-cluster

Os serviços expostos via ServiceExport podem ser acessados usando:

```
<service-name>.<namespace>.svc.clusterset.local
```

Exemplos:
- `hello-app-engine.mcs-demo.svc.clusterset.local`
- `hello-master-engine.mcs-demo.svc.clusterset.local`

## 🔍 Troubleshooting

Consulte [docs/TROUBLESHOOTING_MCS.md](./docs/TROUBLESHOOTING_MCS.md) para problemas comuns e soluções.

### Diagnóstico de Pods Pendentes

Se os pods estiverem em estado `Pending`, execute o script de diagnóstico:

```bash
./scripts/diagnose-pending-pods.sh
```

Este script verifica:
- Nós disponíveis no cluster
- Status e eventos dos pods pendentes
- Recursos disponíveis (CPU/memória)
- Taints e tolerations
- Node selectors
- Requests/limits dos pods

### Resolvendo Problemas de CPU Insuficiente

Se o diagnóstico mostrar "Insufficient cpu" e "max node group size reached", você tem duas opções:

#### Opção 1: Aumentar o max_node_count (Recomendado)

Execute o script para aumentar o limite de nós:

```bash
./scripts/fix-node-pool-scaling.sh
```

Este script aumenta o `max_node_count` de 2 para 4 em ambos os clusters, permitindo que o cluster-autoscaler adicione mais nós quando necessário.

#### Opção 2: Atualizar via Terraform

Edite o arquivo `terraform.tfvars` e aumente o `max_node_count`:

```hcl
gke_clusters = {
  master-engine = {
    # ... outras configurações ...
    max_node_count = 4  # Aumentar de 2 para 4
  }
  app-engine = {
    # ... outras configurações ...
    max_node_count = 4  # Aumentar de 2 para 4
  }
}
```

Depois execute:

```bash
terraform apply
```

#### Opção 3: Reduzir Recursos dos Pods

Os deployments já foram configurados com recursos reduzidos:
- Container principal: 50m CPU / 64Mi memória (requests)
- Sidecar Istio: 100m CPU / 128Mi memória (via annotations)

Se ainda houver problemas, você pode reduzir ainda mais os recursos nos arquivos `deployment.yaml`.

### Verificações Rápidas

```bash
# Verificar status do ServiceExport
kubectl describe serviceexport hello-app-engine -n mcs-demo --context=<contexto>

# Verificar ServiceImports (criados automaticamente)
kubectl get serviceimport -n mcs-demo --context=<contexto>

# Verificar sidecar injection
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
# Deve mostrar: hello-server istio-proxy

# Verificar eventos de um pod pendente
kubectl describe pod <pod-name> -n mcs-demo --context=<contexto>

# Verificar todos os eventos do namespace
kubectl get events -n mcs-demo --context=<contexto> --sort-by='.lastTimestamp'
```

## 📚 Referências

- [Multi-cluster Services Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
