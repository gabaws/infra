# Demo Multi-cluster Services (MCS)

Demonstração de comunicação entre serviços em diferentes clusters GKE usando Multi-cluster Services.

## 📋 Estrutura

```
mcs-demo/
├── README.md
├── docs/
│   ├── Arquitetura.md              # Documentação da arquitetura MCS + ASM
│   └── teste_sem_mcs.md            # Guia para teste sem MCS (ASM-only)
├── scripts/
│   ├── deploy.sh                    # Script de deploy automatizado
│   ├── test-communication.sh        # Script de teste de comunicação
│   ├── test-asm-multicluster-only.sh # Script de teste sem MCS
│   ├── setup-asm-multicluster-only.sh # Script de setup sem MCS
│   ├── fix-node-pool-scaling.sh     # Script para corrigir scaling de nodes
│   ├── force-rollout.sh            # Script para forçar rollout
│   └── check-pods.sh               # Script para verificar pods em ambos clusters
├── app-engine/                      # Aplicação no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── service-export.yaml
│   ├── serviceentry-master.yaml    # ServiceEntry para comunicação sem MCS
│   ├── virtualservice-master.yaml  # VirtualService para comunicação sem MCS
│   └── kustomization.yaml
└── master-engine/                   # Aplicação no cluster master-engine
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── service-export.yaml
    ├── serviceentry-app.yaml       # ServiceEntry para comunicação sem MCS
    ├── virtualservice-app.yaml     # VirtualService para comunicação sem MCS
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

Veja [docs/teste_sem_mcs.md](./docs/teste_sem_mcs.md) para mais detalhes.

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
# Verificar pods em ambos os clusters
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine

# Ou usar o script de verificação
./scripts/check-pods.sh
```

### Acessar Pods para Debug

**⚠️ Motivo do problema**: Os pods têm 2 containers (`hello-server` e `istio-proxy`). Sem especificar o container com `-c`, o kubectl não sabe em qual container executar e o comando trava.

**Comandos corretos:**

```bash
# 1. Especificar o container com -c e usar -it (interactive + tty)
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -c hello-server -- /bin/bash

# 2. Se bash não funcionar, usar sh
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -c hello-server -- /bin/sh

# 3. Para acessar o sidecar istio-proxy (se necessário)
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -c istio-proxy -- /bin/sh

# Verificar containers no pod
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
# Deve mostrar: hello-server istio-proxy
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
# Verificar pods em ambos os clusters
./scripts/check-pods.sh

# Verificar status do ServiceExport
kubectl describe serviceexport hello-app-engine -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl describe serviceexport hello-master-engine -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine

# Verificar ServiceImports (criados automaticamente)
kubectl get serviceimport -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl get serviceimport -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine

# Verificar sidecar injection
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
# Deve mostrar: hello-server istio-proxy

# Acessar pod para testes (usar contexto correto)
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-east1-b_app-engine -- /bin/bash
kubectl exec -n mcs-demo -it <pod-name> --context=gke_infra-474223_us-central1-a_master-engine -- /bin/bash

# Verificar eventos de um pod pendente
kubectl describe pod <pod-name> -n mcs-demo --context=<contexto>

# Verificar todos os eventos do namespace
kubectl get events -n mcs-demo --context=<contexto> --sort-by='.lastTimestamp'
```

## 📚 Documentação

### Documentação do Projeto

- [Arquitetura MCS + ASM](./docs/Arquitetura.md) - Documentação completa da arquitetura, componentes e fluxos
- [Teste sem MCS (ASM-only)](./docs/teste_sem_mcs.md) - Guia para comunicação multi-cluster usando apenas ASM

### Referências Externas

- [Multi-cluster Services Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
