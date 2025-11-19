# Demo Multi-cluster Services (MCS)

Demonstração de comunicação entre serviços em diferentes clusters GKE usando Multi-cluster Services.

## 📋 Estrutura

```
mcs-demo/
├── README.md
├── deploy.sh                    # Script de deploy automatizado
├── test-communication.sh        # Script de teste de comunicação
├── app-engine/                  # Aplicação no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── service-export.yaml
│   └── kustomization.yaml
└── master-engine/               # Aplicação no cluster master-engine
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
./deploy.sh
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

### Teste Automatizado

```bash
./test-communication.sh
```

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

### Verificações Rápidas

```bash
# Verificar status do ServiceExport
kubectl describe serviceexport hello-app-engine -n mcs-demo --context=<contexto>

# Verificar ServiceImports (criados automaticamente)
kubectl get serviceimport -n mcs-demo --context=<contexto>

# Verificar sidecar injection
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
# Deve mostrar: hello-server istio-proxy
```

## 📚 Referências

- [Multi-cluster Services Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
