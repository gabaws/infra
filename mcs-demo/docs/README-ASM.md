# Demo ASM Multi-cluster (sem MCS)

Este diretório contém a configuração para testar comunicação entre clusters usando **Anthos Service Mesh (ASM)** com **East-West Gateway**, sem usar Multi-cluster Services (MCS).

## 📋 Pré-requisitos

1. ✅ Os clusters GKE foram provisionados via Terraform
2. ✅ Os clusters estão registrados no **GKE Hub Fleet**
3. ✅ O **Anthos Service Mesh (ASM)** está habilitado nos clusters
4. ✅ O **East-West Gateway** está instalado em ambos os clusters
5. ✅ `kubectl` e `gcloud` configurados

### ⚠️ Instalar East-West Gateway (Obrigatório)

O East-West Gateway **não é criado automaticamente** pelo ASM gerenciado. Você precisa instalá-lo manualmente:

```bash
cd mcs-demo/scripts
./install-eastwest-gateway.sh
```

Este script irá:
- Instalar o gateway em ambos os clusters
- Configurar como LoadBalancer
- Aguardar os IPs ficarem disponíveis

**Aguarde 2-3 minutos** após a instalação para os IPs ficarem prontos.

## 🔧 Componentes

### Manifestos ASM

#### app-engine/
- `deployment.yaml` - Deployment do serviço hello-app-engine
- `service.yaml` - Service Kubernetes
- `serviceentry-master.yaml` - ServiceEntry para acessar serviço no master-engine
- `destinationrule-master.yaml` - DestinationRule com mTLS e load balancing
- `virtualservice-master.yaml` - VirtualService para roteamento

#### master-engine/
- `deployment.yaml` - Deployment do serviço hello-master-engine
- `service.yaml` - Service Kubernetes
- `serviceentry-app.yaml` - ServiceEntry para acessar serviço no app-engine
- `destinationrule-app.yaml` - DestinationRule com mTLS e load balancing
- `virtualservice-app.yaml` - VirtualService para roteamento

## 🚀 Deploy

### Script Automatizado (Recomendado)

```bash
cd mcs-demo/scripts
./deploy-asm.sh
```

O script irá:
1. Conectar aos clusters
2. Obter automaticamente os IPs dos East-West Gateways
3. Atualizar os ServiceEntry com os IPs corretos
4. Fazer deploy de todos os recursos

### Deploy Manual

1. **Obter IPs dos East-West Gateways:**

```bash
# IP do gateway do app-engine
APP_GW_IP=$(kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# IP do gateway do master-engine
MASTER_GW_IP=$(kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

2. **Atualizar ServiceEntry com os IPs:**

Edite `app-engine/serviceentry-master.yaml` e substitua `PLACEHOLDER_MASTER_ENGINE_GW_IP` pelo IP do gateway do master-engine.

Edite `master-engine/serviceentry-app.yaml` e substitua `PLACEHOLDER_APP_ENGINE_GW_IP` pelo IP do gateway do app-engine.

3. **Deploy:**

```bash
# Cluster app-engine
cd app-engine
kubectl apply -k . --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
cd ../master-engine
kubectl apply -k . --context=gke_infra-474223_us-central1-a_master-engine
```

## 🧪 Testar Comunicação

### Script Automatizado

```bash
cd mcs-demo/scripts
./test-communication-asm.sh
```

### Teste Manual

#### 1. Do app-engine para master-engine:

```bash
APP_POD=$(kubectl get pods -n mcs-demo -l app=hello-app-engine \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec $APP_POD -n mcs-demo -c hello-server \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -- curl -s http://hello-master-engine.mcs-demo.global:80
```

#### 2. Do master-engine para app-engine:

```bash
MASTER_POD=$(kubectl get pods -n mcs-demo -l app=hello-master-engine \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec $MASTER_POD -n mcs-demo -c hello-server \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -- curl -s http://hello-app-engine.mcs-demo.global:80
```

## 🌐 Formato DNS

Para comunicação cross-cluster com ASM, use o formato:

```
<service-name>.<namespace>.global
```

Exemplos:
- `hello-master-engine.mcs-demo.global`
- `hello-app-engine.mcs-demo.global`

**⚠️ Importante:** Note o sufixo `.global` ao invés de `.cluster.local` ou `.clusterset.local`

## 🔍 Verificar Status

### Verificar ServiceEntry

```bash
# Cluster app-engine
kubectl get serviceentry -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl get serviceentry -n mcs-demo \
  --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar East-West Gateway

```bash
# Cluster app-engine
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine
```

### Verificar mTLS

```bash
# Verificar se os pods têm sidecar Istio
kubectl get pods -n mcs-demo \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

## 🗑️ Limpar Deploy

```bash
# Remover recursos do app-engine
kubectl delete -k app-engine --context=gke_infra-474223_us-east1-b_app-engine

# Remover recursos do master-engine
kubectl delete -k master-engine --context=gke_infra-474223_us-central1-a_master-engine
```

## 📚 Diferenças entre ASM e MCS

| Característica | ASM (.global) | MCS (.clusterset.local) |
|----------------|---------------|------------------------|
| Configuração | Manual (ServiceEntry) | Automática (ServiceExport) |
| DNS | `.global` | `.clusterset.local` |
| Descoberta | ServiceEntry + Gateway | ServiceExport/Import automático |
| Gateway | East-West Gateway manual | Automático via Traffic Director |

## 🔗 Referências

- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
- [Istio ServiceEntry](https://istio.io/latest/docs/reference/config/networking/service-entry/)
- [Istio Multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/)

