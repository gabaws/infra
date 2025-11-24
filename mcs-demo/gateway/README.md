# East-West Gateway para ASM Multi-cluster

Este diretório contém os manifestos necessários para instalar o **East-West Gateway** em clusters GKE com Anthos Service Mesh (ASM) para comunicação entre clusters **sem usar Traffic Director ou MCS**.

## 📚 Documentação Oficial do Google Cloud

### Documentação Principal do ASM Multi-cluster

1. **Anthos Service Mesh - Multi-cluster Setup (Managed Mode)**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#multi-cluster-setup
   - Descrição: Guia oficial para configurar ASM multi-cluster em modo gerenciado
   - **Este é o documento principal que você deve consultar**

2. **Installing East-West Gateway for Multi-cluster**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#east-west-gateway
   - Descrição: Instruções específicas para instalar o gateway East-West no ASM gerenciado
   - **Contém os passos exatos para instalação do gateway**

3. **Cross-cluster Communication with ServiceEntry**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#cross-cluster-communication
   - Descrição: Como configurar comunicação entre clusters usando ServiceEntry (sem MCS)
   - **Explica como usar ServiceEntry para comunicação cross-cluster**

4. **ASM Managed Mode - Complete Documentation**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh
   - Descrição: Documentação completa do ASM em modo gerenciado
   - **Índice principal de toda documentação do ASM**

### Documentação Específica

5. **ServiceEntry API Reference**
   - URL: https://istio.io/latest/docs/reference/config/networking/service-entry/
   - Descrição: Referência completa da API ServiceEntry do Istio
   - **Para entender todos os campos do ServiceEntry**

6. **Gateway API Reference**
   - URL: https://istio.io/latest/docs/reference/config/networking/gateway/
   - Descrição: Referência de configuração do Gateway (Istio)
   - **Para configurações avançadas do gateway**

7. **Multi-cluster Setup without Traffic Director**
   - URL: https://istio.io/latest/docs/setup/install/multicluster/
   - Descrição: Documentação do Istio sobre setup multi-cluster
   - **Aborda comunicação entre clusters sem Traffic Director**

### Artigos Relacionados

- **ASM Architecture**: https://cloud.google.com/service-mesh/docs/architecture
- **ASM Troubleshooting**: https://cloud.google.com/service-mesh/docs/troubleshooting
- **Istio Multi-cluster**: https://istio.io/latest/docs/ops/deployment/deployment-models/#multiple-clusters

## 📋 Pré-requisitos

1. ✅ Clusters GKE provisionados
2. ✅ ASM habilitado em ambos os clusters (`MANAGEMENT_AUTOMATIC`)
3. ✅ Clusters registrados no GKE Hub Fleet
4. ✅ `kubectl` e `gcloud` configurados

## 🚀 Instalação do Gateway

### Passo 1: Obter Informações do Cluster

Antes de instalar, você precisa obter:

1. **Mesh ID** (Project Number):
```bash
gcloud projects describe infra-474223 --format="value(projectNumber)"
```

2. **Revisão do ASM**:
```bash
# Cluster app-engine
kubectl get deployment -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}'

# Cluster master-engine
kubectl get deployment -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}'
```

3. **Imagem do Proxy**:
```bash
# Obter a imagem do istio-proxy usada pelo ASM
kubectl get deployment -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' | sed 's/istiod/istio-proxy/g'
```

### Passo 2: Editar os Manifestos

Edite os arquivos em `gateway/app-engine/` e `gateway/master-engine/`:

1. Substitua `MESH_ID` pelo project number
2. Substitua `ASM_REVISION` pela revisão obtida
3. Substitua `PROXY_IMAGE` pela imagem do proxy (ou use `auto`)

### Passo 3: Aplicar os Manifestos

```bash
# Cluster app-engine
kubectl apply -f gateway/app-engine/ \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl apply -f gateway/master-engine/ \
  --context=gke_infra-474223_us-central1-a_master-engine
```

### Passo 4: Aguardar IPs do LoadBalancer

```bash
# Verificar IPs
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine

kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine
```

Aguarde 2-5 minutos para os IPs ficarem disponíveis.

## 🔧 Configuração dos ServiceEntry

Após obter os IPs dos gateways, atualize os ServiceEntry:

1. **app-engine/serviceentry-master.yaml**: Substitua `PLACEHOLDER_MASTER_ENGINE_GW_IP` pelo IP do gateway do master-engine
2. **master-engine/serviceentry-app.yaml**: Substitua `PLACEHOLDER_APP_ENGINE_GW_IP` pelo IP do gateway do app-engine

## 📖 Referências Adicionais

- **Istio Multi-cluster Setup**: https://istio.io/latest/docs/setup/install/multicluster/
- **ServiceEntry API Reference**: https://istio.io/latest/docs/reference/config/networking/service-entry/
- **Gateway API Reference**: https://istio.io/latest/docs/reference/config/networking/gateway/

## ⚠️ Notas Importantes

- O gateway East-West **não é criado automaticamente** pelo ASM gerenciado
- Cada cluster precisa do seu próprio gateway
- Os gateways são expostos como LoadBalancer (IPs públicos)
- Para produção, considere adicionar regras de firewall para restringir acesso
- A comunicação usa mTLS automaticamente via ASM

