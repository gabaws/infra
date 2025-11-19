# Teste de Comunicação Multi-cluster usando apenas ASM (SEM MCS)

Este guia mostra como testar comunicação entre clusters usando apenas **ASM Multi-cluster (connected mode)** sem habilitar **MCS (Multi-cluster Services)**.

## 🎯 Objetivo

Simular o cenário onde:
- ✅ ASM Multi-cluster está conectado (`multicluster_mode: connected`)
- ❌ MCS NÃO está habilitado
- ✅ Comunicação entre clusters funciona via ServiceEntry + VirtualService

## 📋 Pré-requisitos

1. ASM Multi-cluster conectado (verificar: `kubectl get configmap asm-options -n istio-system`)
2. Dois clusters GKE com ASM habilitado
3. Aplicações deployadas em ambos os clusters
4. `kubectl` configurado com contextos para ambos os clusters

## 🚀 Como Usar

### Passo 1: Configurar ServiceEntry e VirtualService

Execute o script que cria automaticamente os recursos necessários:

```bash
cd /home/user/infra/mcs-demo
./scripts/setup-asm-multicluster-only.sh
```

Este script:
1. Obtém os ClusterIPs dos serviços em ambos os clusters
2. Cria ServiceEntry em cada cluster apontando para o serviço remoto
3. Cria VirtualService para roteamento

### Passo 2: Testar Comunicação

Execute o script de teste:

```bash
./scripts/test-asm-multicluster-only.sh
```

## 📊 Como Funciona

### ServiceEntry

O ServiceEntry define um serviço "externo" à malha que na verdade está em outro cluster:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: hello-master-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-master-engine-remote.mcs-demo.svc.cluster.local
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: STATIC
  addresses:
  - <CLUSTER_IP_DO_SERVICO_REMOTO>
  location: MESH_INTERNAL
  endpoints:
  - address: <CLUSTER_IP_DO_SERVICO_REMOTO>
    ports:
      http: 80
```

**Pontos importantes:**
- `hosts`: Define o hostname que será usado para acessar o serviço
- `addresses`: ClusterIP do serviço no cluster remoto
- `endpoints`: Endpoints estáticos apontando para o ClusterIP
- `location: MESH_INTERNAL`: Indica que está dentro da malha (não é externo)

### VirtualService

O VirtualService define regras de roteamento:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: hello-master-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-master-engine-remote.mcs-demo.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: hello-master-engine-remote.mcs-demo.svc.cluster.local
        port:
          number: 80
      weight: 100
```

## 🔍 Diferenças: ASM-only vs MCS

| Característica | ASM-only (ServiceEntry) | MCS (ServiceExport) |
|----------------|-------------------------|---------------------|
| **DNS** | `service-remote.namespace.svc.cluster.local` (customizado) | `service.namespace.svc.clusterset.local` (automático) |
| **Configuração** | Manual (precisa criar ServiceEntry + VirtualService) | Automática (apenas ServiceExport) |
| **ClusterIP** | Precisa saber o ClusterIP do serviço remoto | Não precisa saber (descoberta automática) |
| **ServiceImport** | Não usa | Criado automaticamente |
| **Serviços gke-mcs-*** | Não cria | Criados automaticamente |
| **Requer MCS** | ❌ Não | ✅ Sim |

## 🧪 Teste Manual

### Teste 1: De app-engine para master-engine

```bash
# Obter pod
APP_POD=$(kubectl get pods -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}')

# Testar comunicação
kubectl exec $APP_POD -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine -c hello-server -- \
  curl -i http://hello-master-engine-remote.mcs-demo.svc.cluster.local
```

### Teste 2: De master-engine para app-engine

```bash
# Obter pod
MASTER_POD=$(kubectl get pods -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}')

# Testar comunicação
kubectl exec $MASTER_POD -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine -c hello-server -- \
  curl -i http://hello-app-engine-remote.mcs-demo.svc.cluster.local
```

## 🔧 Verificação

### Verificar ServiceEntry

```bash
# Cluster app-engine
kubectl get serviceentry hello-master-engine-remote -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine -o yaml

# Cluster master-engine
kubectl get serviceentry hello-app-engine-remote -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine -o yaml
```

### Verificar VirtualService

```bash
# Cluster app-engine
kubectl get virtualservice hello-master-engine-remote -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine -o yaml

# Cluster master-engine
kubectl get virtualservice hello-app-engine-remote -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine -o yaml
```

## ⚠️ Limitações

1. **ClusterIP estático**: Se o ClusterIP mudar, precisa atualizar o ServiceEntry manualmente
2. **Configuração manual**: Precisa criar ServiceEntry e VirtualService para cada serviço
3. **DNS customizado**: Não usa o formato padrão `svc.clusterset.local`
4. **Não escala bem**: Para muitos serviços, fica trabalhoso manter

## 💡 Quando Usar

**Use ASM-only (ServiceEntry) quando:**
- ✅ Você não pode habilitar MCS no Fleet
- ✅ Você precisa de controle fino sobre roteamento
- ✅ Você tem poucos serviços para expor
- ✅ Você quer testar comunicação sem MCS

**Use MCS quando:**
- ✅ Você pode habilitar MCS no Fleet
- ✅ Você quer descoberta automática de serviços
- ✅ Você tem muitos serviços para expor
- ✅ Você quer usar o formato padrão `svc.clusterset.local`

## 🧹 Limpeza

Para remover os recursos criados:

```bash
# Cluster app-engine
kubectl delete serviceentry hello-master-engine-remote -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine
kubectl delete virtualservice hello-master-engine-remote -n mcs-demo --context=gke_infra-474223_us-east1-b_app-engine

# Cluster master-engine
kubectl delete serviceentry hello-app-engine-remote -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
kubectl delete virtualservice hello-app-engine-remote -n mcs-demo --context=gke_infra-474223_us-central1-a_master-engine
```

## 📚 Referências

- [ServiceEntry Documentation](https://istio.io/latest/docs/reference/config/networking/service-entry/)
- [VirtualService Documentation](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [ASM Multi-cluster](https://cloud.google.com/service-mesh/docs/supported-features-managed?hl=pt-br#multi-cluster_deployment)
