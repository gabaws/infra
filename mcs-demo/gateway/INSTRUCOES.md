# Instruções de Instalação do East-West Gateway

## 📋 Passo a Passo

### 1. Obter Informações Necessárias

Execute os comandos abaixo para obter as informações que precisam ser substituídas nos manifestos:

```bash
# Mesh ID (Project Number)
MESH_ID=$(gcloud projects describe infra-474223 --format="value(projectNumber)")
echo "Mesh ID: $MESH_ID"

# Revisão do ASM no cluster app-engine
APP_REV=$(kubectl get deployment -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}')
echo "app-engine ASM revision: $APP_REV"

# Revisão do ASM no cluster master-engine
MASTER_REV=$(kubectl get deployment -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}')
echo "master-engine ASM revision: $MASTER_REV"
```

### 2. Editar os Manifestos

Edite os arquivos `app-engine/gateway.yaml` e `master-engine/gateway.yaml`:

1. Substitua `MESH_ID` pelo project number obtido acima
2. Substitua `asm-managed` pela revisão correta do ASM (se diferente)

**Exemplo:**
- Se `MESH_ID = 123456789`, substitua `proj-MESH_ID` por `proj-123456789`
- Se a revisão for `asm-1272-1`, substitua `asm-managed` por `asm-1272-1`

### 3. Instalar os Gateways

#### Opção A: Usando o Script Automatizado

```bash
cd mcs-demo/gateway
./install.sh
```

O script irá:
- Obter automaticamente o Mesh ID
- Obter as revisões do ASM
- Atualizar os manifestos
- Instalar os gateways em ambos os clusters

#### Opção B: Instalação Manual

```bash
# Cluster app-engine
kubectl apply -f gateway/app-engine/gateway.yaml \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl apply -f gateway/master-engine/gateway.yaml \
  --context=gke_infra-474223_us-central1-a_master-engine
```

### 4. Aguardar IPs do LoadBalancer

Aguarde 2-5 minutos e verifique os IPs:

```bash
# IP do gateway app-engine
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# IP do gateway master-engine
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 5. Atualizar ServiceEntry

Após obter os IPs, atualize os ServiceEntry:

1. **app-engine/serviceentry-master.yaml**: Substitua `PLACEHOLDER_MASTER_ENGINE_GW_IP` pelo IP do gateway do master-engine
2. **master-engine/serviceentry-app.yaml**: Substitua `PLACEHOLDER_APP_ENGINE_GW_IP` pelo IP do gateway do app-engine

### 6. Fazer Deploy das Aplicações

```bash
cd mcs-demo/scripts
./deploy-asm.sh
```

## 🔍 Verificação

Verifique se os gateways estão funcionando:

```bash
# Verificar pods do gateway
kubectl get pods -n istio-system -l istio=eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine

kubectl get pods -n istio-system -l istio=eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine

# Verificar logs (se necessário)
kubectl logs -n istio-system -l istio=eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine
```

## 🗑️ Remover Gateways

Se precisar remover os gateways:

```bash
# Cluster app-engine
kubectl delete -f gateway/app-engine/gateway.yaml \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl delete -f gateway/master-engine/gateway.yaml \
  --context=gke_infra-474223_us-central1-a_master-engine
```

