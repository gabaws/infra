# Demo Multi-cluster Services (MCS)

Este diretório contém os manifestos para testar a comunicação entre serviços em diferentes clusters usando Multi-cluster Services, seguindo a [documentação oficial do Google](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services?hl=pt-br).

## 📋 Estrutura

```
mcs-demo/
├── README.md                    # Este arquivo
├── app-engine/                  # Aplicação no cluster app-engine
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── multicluster-service.yaml
│   └── kustomization.yaml
└── master-engine/              # Aplicação no cluster master-engine
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── multicluster-service.yaml
    └── kustomization.yaml
```

## 🎯 Aplicações

### Cluster app-engine
- **Aplicação**: `hello-app-engine`
- **Imagem**: `gcr.io/google-samples/hello-app:1.0`
- **Porta**: 8080 (exposta como 80 no Service)
- **Replicas**: 2

### Cluster master-engine
- **Aplicação**: `hello-master-engine`
- **Imagem**: `gcr.io/google-samples/hello-app:1.0`
- **Porta**: 8080 (exposta como 80 no Service)
- **Replicas**: 2

## 🚀 Deploy

### Pré-requisitos

1. ✅ Multi-cluster Services habilitado no Fleet
2. ✅ Clusters registrados no Fleet
3. ✅ `kubectl` configurado com acesso aos clusters

### Passo 1: Conectar aos clusters

```bash
# Conectar ao cluster app-engine
gcloud container clusters get-credentials app-engine \
  --location=us-east1-b \
  --project=infra-474223

# Conectar ao cluster master-engine
gcloud container clusters get-credentials master-engine \
  --location=us-central1-a \
  --project=infra-474223
```

### Passo 2: Deploy no cluster app-engine

```bash
cd app-engine
kubectl apply -k .
```

### Passo 3: Deploy no cluster master-engine

```bash
cd ../master-engine
kubectl apply -k .
```

## ✅ Verificação

### Verificar pods

```bash
# No cluster app-engine
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine

# No cluster master-engine
kubectl get pods -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar serviços

```bash
# No cluster app-engine
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine

# No cluster master-engine
kubectl get svc -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar MultiClusterServices

```bash
# No cluster app-engine
kubectl get multiclusterservice -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine

# No cluster master-engine
kubectl get multiclusterservice -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

## 🔧 Sidecar Istio

Os pods têm injeção automática do sidecar do Istio habilitada via:
- **Labels no namespace**: `istio-injection: enabled` e `istio.io/rev: asm-managed`
- **Anotações nos pods**: `sidecar.istio.io/inject: "true"`

Verifique se o sidecar foi injetado:
```bash
kubectl get pods -n mcs-demo
# Deve mostrar 2/2 containers (app + istio-proxy)
```

Veja mais detalhes em [docs/ISTIO_SIDECAR_INJECTION.md](./docs/ISTIO_SIDECAR_INJECTION.md)

## 🧪 Testes de Comunicação

### Teste 1: De app-engine para master-engine

```bash
# Criar pod de teste no cluster app-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -- sh

# Dentro do pod, testar comunicação:
curl http://hello-master-engine.mcs-demo.svc.clusterset.local
```

### Teste 2: De master-engine para app-engine

```bash
# Criar pod de teste no cluster master-engine
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -- sh

# Dentro do pod, testar comunicação:
curl http://hello-app-engine.mcs-demo.svc.clusterset.local
```

### Teste 3: DNS lookup

```bash
# No pod de teste, verificar resolução DNS:
nslookup hello-master-engine.mcs-demo.svc.clusterset.local
nslookup hello-app-engine.mcs-demo.svc.clusterset.local
```

## 📝 Formato DNS Multi-cluster

Os serviços expostos via MultiClusterService podem ser acessados usando o formato:

```
<service-name>.<namespace>.svc.clusterset.local
```

Exemplos:
- `hello-app-engine.mcs-demo.svc.clusterset.local`
- `hello-master-engine.mcs-demo.svc.clusterset.local`

## 🔍 Troubleshooting

### Verificar status do MultiClusterService

```bash
kubectl describe multiclusterservice hello-app-engine -n mcs-demo
kubectl describe multiclusterservice hello-master-engine -n mcs-demo
```

### Verificar logs dos pods

```bash
# Cluster app-engine
kubectl logs -l app=hello-app-engine -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl logs -l app=hello-master-engine -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar conectividade de rede

```bash
# Testar conectividade básica
kubectl run nettest --image=nicolaka/netshoot:latest --rm -it --restart=Never -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -- curl -v http://hello-master-engine.mcs-demo.svc.clusterset.local
```

## 📚 Referências

- [Multi-cluster Services Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services?hl=pt-br)
- [MultiClusterService Resource](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#create_multiclusterservice)
