# 🚀 Quick Start - Multi-cluster Services Demo

Guia rápido para fazer deploy e testar comunicação entre clusters usando Multi-cluster Services.

## ✅ Pré-requisitos Verificados

- ✅ Multi-cluster Services habilitado no Fleet
- ✅ Clusters `app-engine` e `master-engine` registrados no Fleet
- ✅ Workload Identity configurado nos clusters

## 📦 Deploy Rápido

### Opção 1: Script Automatizado (Recomendado)

```bash
cd mcs-demo
./deploy.sh
```

### Opção 2: Manual

```bash
# 1. Conectar aos clusters
gcloud container clusters get-credentials app-engine \
  --location=us-east1-b --project=infra-474223

gcloud container clusters get-credentials master-engine \
  --location=us-central1-a --project=infra-474223

# 2. Deploy no app-engine
cd app-engine
kubectl apply -k .

# 3. Deploy no master-engine
cd ../master-engine
kubectl apply -k .
```

## 🧪 Testar Comunicação

### Opção 1: Script Automatizado

```bash
cd mcs-demo
./test-communication.sh
```

### Opção 2: Teste Manual

**Teste de app-engine → master-engine:**
```bash
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -- curl http://hello-master-engine.mcs-demo.svc.clusterset.local
```

**Teste de master-engine → app-engine:**
```bash
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -- curl http://hello-app-engine.mcs-demo.svc.clusterset.local
```

## 📊 Verificar Status

```bash
# Ver pods
kubectl get pods -n mcs-demo --all-namespaces

# Ver serviços
kubectl get svc -n mcs-demo --all-namespaces

# Ver MultiClusterServices
kubectl get multiclusterservice -n mcs-demo --all-namespaces

# Ver detalhes de um MultiClusterService
kubectl describe multiclusterservice hello-app-engine -n mcs-demo
```

## 🎯 Formato DNS

Os serviços podem ser acessados usando:

```
<service-name>.<namespace>.svc.clusterset.local
```

Exemplos:
- `hello-app-engine.mcs-demo.svc.clusterset.local`
- `hello-master-engine.mcs-demo.svc.clusterset.local`

## 🔍 Troubleshooting

### Verificar se Multi-cluster Services está ativo

```bash
gcloud container fleet multi-cluster-services describe --project=infra-474223
```

### Ver logs dos pods

```bash
# Cluster app-engine
kubectl logs -l app=hello-app-engine -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl logs -l app=hello-master-engine -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar conectividade de rede

```bash
# Teste DNS
kubectl run dns-test --image=nicolaka/netshoot:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -- nslookup hello-master-engine.mcs-demo.svc.clusterset.local
```

## 📚 Documentação

- [Multi-cluster Services - Google Cloud](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services?hl=pt-br)
- [README.md](./README.md) - Documentação completa
