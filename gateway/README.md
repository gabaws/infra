# East-West Gateway para ASM Multi-cluster

Este diretório contém os manifestos e scripts necessários para instalar o **East-West Gateway** em clusters GKE com Anthos Service Mesh (ASM) para comunicação entre clusters **sem usar Traffic Director ou MCS**.

## 📋 Pré-requisitos

1. ✅ Clusters GKE provisionados
2. ✅ ASM habilitado em ambos os clusters (`MANAGEMENT_AUTOMATIC`)
3. ✅ Clusters registrados no GKE Hub Fleet
4. ✅ `kubectl` e `gcloud` configurados

## 🚀 Instalação Rápida (Recomendado)

Use o script automatizado que faz tudo para você:

```bash
cd gateway
chmod +x scripts/install.sh
./scripts/install.sh
```

O script irá:
- ✅ Obter automaticamente o Mesh ID (project number)
- ✅ Obter as revisões do ASM de cada cluster
- ✅ Extrair os certificados CA do istiod
- ✅ Criar os ConfigMaps necessários
- ✅ Atualizar os manifestos com os valores corretos
- ✅ Instalar os gateways em ambos os clusters via Kustomize
- ✅ Aguardar os deployments ficarem prontos

## 📝 Estrutura do Diretório

```
gateway/
├── README.md                    # Esta documentação
├── app-engine/
│   ├── configmap-ca-cert.yaml  # ConfigMap do certificado CA
│   ├── gateway.yaml            # Manifestos do gateway
│   └── kustomization.yaml      # Kustomization para este cluster
├── master-engine/
│   ├── configmap-ca-cert.yaml  # ConfigMap do certificado CA
│   ├── gateway.yaml            # Manifestos do gateway
│   └── kustomization.yaml      # Kustomization para este cluster
└── scripts/
    ├── install.sh              # Script de instalação automatizada
    └── diagnostic.sh           # Script de diagnóstico de problemas
```

## 🔧 Instalação Manual

Se preferir instalar manualmente:

### 1. Obter Informações Necessárias

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

### 2. Obter Certificado CA do istiod

```bash
# Para app-engine
ISTIOD_POD=$(kubectl get pods -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n istio-system --context=gke_infra-474223_us-east1-b_app-engine \
  $ISTIOD_POD -c discovery -- cat /var/run/secrets/istio/root-cert.pem > /tmp/app-ca-cert.pem

# Para master-engine
ISTIOD_POD=$(kubectl get pods -n istio-system -l app=istiod \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n istio-system --context=gke_infra-474223_us-central1-a_master-engine \
  $ISTIOD_POD -c discovery -- cat /var/run/secrets/istio/root-cert.pem > /tmp/master-ca-cert.pem
```

### 3. Criar ConfigMaps com os Certificados

```bash
# Criar ConfigMap para app-engine
kubectl create configmap istio-ca-root-cert \
  --from-file=root-cert.pem=/tmp/app-ca-cert.pem \
  -n istio-system \
  --context=gke_infra-474223_us-east1-b_app-engine \
  --dry-run=client -o yaml | kubectl apply --context=gke_infra-474223_us-east1-b_app-engine -f -

# Criar ConfigMap para master-engine
kubectl create configmap istio-ca-root-cert \
  --from-file=root-cert.pem=/tmp/master-ca-cert.pem \
  -n istio-system \
  --context=gke_infra-474223_us-central1-a_master-engine \
  --dry-run=client -o yaml | kubectl apply --context=gke_infra-474223_us-central1-a_master-engine -f -
```

### 4. Editar os Manifestos

Edite os arquivos `app-engine/gateway.yaml` e `master-engine/gateway.yaml`:
- Substitua `MESH_ID` pelo project number obtido
- Substitua `asm-managed` pela revisão correta do ASM (se diferente)

**Exemplo:**
- Se `MESH_ID = 123456789`, substitua `proj-MESH_ID` por `proj-123456789`
- Se a revisão for `asm-1272-1`, substitua `asm-managed` por `asm-1272-1`

### 5. Aplicar os Manifestos via Kustomize

```bash
# Cluster app-engine
kubectl apply -k app-engine/ \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl apply -k master-engine/ \
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

# Obter IPs dos LoadBalancers
kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-east1-b_app-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

kubectl get svc -n istio-system istio-eastwestgateway \
  --context=gke_infra-474223_us-central1-a_master-engine \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔍 Diagnóstico de Problemas

Se os pods do gateway estiverem presos em `ContainerCreating` ou não estiverem iniciando corretamente, execute o script de diagnóstico:

```bash
cd gateway
chmod +x scripts/diagnostic.sh
./scripts/diagnostic.sh
```

O script verifica:
- ✅ Status dos pods e deployments
- ✅ ConfigMaps necessários (istio-ca-root-cert)
- ✅ ServiceAccounts e permissões
- ✅ Recursos dos nós (CPU, memória)
- ✅ Eventos e logs relevantes
- ✅ Configuração de volumes e containers

### Comandos Úteis para Troubleshooting

```bash
# Ver eventos do pod
kubectl describe pod <nome-do-pod> -n istio-system --context=<contexto>

# Ver logs do pod
kubectl logs <nome-do-pod> -n istio-system --context=<contexto>

# Verificar ConfigMaps disponíveis
kubectl get configmap -n istio-system --context=<contexto>

# Verificar ServiceAccount
kubectl get serviceaccount istio-eastwestgateway-service-account -n istio-system --context=<contexto>

# Verificar eventos recentes do namespace
kubectl get events -n istio-system --context=<contexto> --sort-by='.lastTimestamp'
```

## 🔧 Configuração dos ServiceEntry

Após obter os IPs dos gateways, atualize os ServiceEntry nos manifestos das aplicações:

1. **app-demo/app-engine/serviceentry-master.yaml**: Substitua `PLACEHOLDER_MASTER_ENGINE_GW_IP` pelo IP do gateway do master-engine
2. **app-demo/master-engine/serviceentry-app.yaml**: Substitua `PLACEHOLDER_APP_ENGINE_GW_IP` pelo IP do gateway do app-engine

## 🗑️ Remover Gateways

Se precisar remover os gateways:

```bash
# Cluster app-engine
kubectl delete -k app-engine/ \
  --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl delete -k master-engine/ \
  --context=gke_infra-474223_us-central1-a_master-engine
```

## 📚 Documentação Oficial do Google Cloud

### Documentação Principal do ASM Multi-cluster

1. **Anthos Service Mesh - Multi-cluster Setup (Managed Mode)**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#multi-cluster-setup
   - Descrição: Guia oficial para configurar ASM multi-cluster em modo gerenciado

2. **Installing East-West Gateway for Multi-cluster**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#east-west-gateway
   - Descrição: Instruções específicas para instalar o gateway East-West no ASM gerenciado

3. **Cross-cluster Communication with ServiceEntry**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh#cross-cluster-communication
   - Descrição: Como configurar comunicação entre clusters usando ServiceEntry (sem MCS)

4. **ASM Managed Mode - Complete Documentation**
   - URL: https://cloud.google.com/service-mesh/docs/managed/service-mesh
   - Descrição: Documentação completa do ASM em modo gerenciado

### Documentação Específica

5. **ServiceEntry API Reference**
   - URL: https://istio.io/latest/docs/reference/config/networking/service-entry/
   - Descrição: Referência completa da API ServiceEntry do Istio

6. **Gateway API Reference**
   - URL: https://istio.io/latest/docs/reference/config/networking/gateway/
   - Descrição: Referência de configuração do Gateway (Istio)

7. **Multi-cluster Setup without Traffic Director**
   - URL: https://istio.io/latest/docs/setup/install/multicluster/
   - Descrição: Documentação do Istio sobre setup multi-cluster

### Artigos Relacionados

- **ASM Architecture**: https://cloud.google.com/service-mesh/docs/architecture
- **ASM Troubleshooting**: https://cloud.google.com/service-mesh/docs/troubleshooting
- **Istio Multi-cluster**: https://istio.io/latest/docs/ops/deployment/deployment-models/#multiple-clusters

## ⚠️ Notas Importantes

- O gateway East-West **não é criado automaticamente** pelo ASM gerenciado
- Cada cluster precisa do seu próprio gateway
- Os gateways são expostos como LoadBalancer (IPs públicos)
- Para produção, considere adicionar regras de firewall para restringir acesso
- A comunicação usa mTLS automaticamente via ASM
- O ConfigMap `istio-env` **não existe** no ASM gerenciado - não deve ser referenciado nos manifestos
- O ConfigMap `istio-ca-root-cert` **deve ser criado** - o script de instalação faz isso automaticamente
