# Quick Start - East-West Gateway

## 🚀 Instalação Rápida

### 1. Usando o Script Automatizado (Recomendado)

```bash
cd mcs-demo/gateway
chmod +x install.sh
./install.sh
```

O script irá:
- ✅ Obter automaticamente o Mesh ID (project number)
- ✅ Obter as revisões do ASM de cada cluster
- ✅ Atualizar os manifestos com os valores corretos
- ✅ Instalar os gateways em ambos os clusters
- ✅ Aguardar os deployments ficarem prontos

### 2. Instalação Manual

Se preferir fazer manualmente:

```bash
# 1. Obter Mesh ID
MESH_ID=$(gcloud projects describe infra-474223 --format="value(projectNumber)")

# 2. Editar os manifestos:
#    - gateway/app-engine/gateway.yaml: substituir MESH_ID
#    - gateway/master-engine/gateway.yaml: substituir MESH_ID

# 3. Aplicar
kubectl apply -f gateway/app-engine/gateway.yaml \
  --context=gke_infra-474223_us-east1-b_app-engine

kubectl apply -f gateway/master-engine/gateway.yaml \
  --context=gke_infra-474223_us-central1-a_master-engine
```

## 📊 Verificar Instalação

```bash
# Verificar pods
kubectl get pods -n istio-system -l istio=eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine

kubectl get pods -n istio-system -l istio=eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine

# Verificar IPs (aguarde 2-5 minutos)
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine

kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine
```

## 🔗 Próximos Passos

Após obter os IPs dos gateways:

1. Atualize os ServiceEntry com os IPs:
   - `../app-engine/serviceentry-master.yaml` → substituir `PLACEHOLDER_MASTER_ENGINE_GW_IP`
   - `../master-engine/serviceentry-app.yaml` → substituir `PLACEHOLDER_APP_ENGINE_GW_IP`

2. Faça o deploy das aplicações:
   ```bash
   cd ../scripts
   ./deploy-asm.sh
   ```

3. Teste a comunicação:
   ```bash
   ./test-communication-asm.sh
   ```

## 📚 Documentação Oficial

Consulte `README.md` para links completos da documentação oficial do Google Cloud sobre ASM multi-cluster com East-West Gateway.

