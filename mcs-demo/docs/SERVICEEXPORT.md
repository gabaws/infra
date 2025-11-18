# ServiceExport - Multi-cluster Services

## 📋 Visão Geral

O `ServiceExport` é o recurso correto para exportar serviços entre clusters no Google Cloud Multi-cluster Services.

## ✅ Formato Correto

```yaml
apiVersion: net.gke.io/v1
kind: ServiceExport
metadata:
  namespace: <namespace>  # Deve corresponder ao namespace do Service
  name: <service-name>    # Deve corresponder ao nome do Service
```

**Importante**: Não há um campo `spec` - apenas `metadata` com `namespace` e `name`.

## 🔄 Como Funciona

1. **Criar o Service primeiro**: O Service normal do Kubernetes deve existir no cluster
2. **Criar o ServiceExport**: O ServiceExport referencia o Service pelo nome e namespace
3. **Sincronização automática**: O GKE Hub sincroniza o Service para outros clusters do Fleet
4. **DNS automático**: O DNS `servicename.namespace.svc.clusterset.local` é criado automaticamente

## 📝 Exemplo Completo

### Service (hello-app-engine)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-app-engine
  namespace: mcs-demo
spec:
  selector:
    app: hello-app-engine
  ports:
  - port: 80
    targetPort: 8080
```

### ServiceExport (hello-app-engine)
```yaml
apiVersion: net.gke.io/v1
kind: ServiceExport
metadata:
  namespace: mcs-demo
  name: hello-app-engine
```

## ⏱️ Tempo de Sincronização

- **Primeira exportação**: ~5 minutos para sincronizar com outros clusters
- **Sincronizações subsequentes**: Imediatas quando endpoints mudam

## 🌐 DNS Multi-cluster

Após criar o `ServiceExport`, o serviço pode ser acessado de qualquer pod em qualquer cluster do Fleet usando:

```
<service-name>.<namespace>.svc.clusterset.local
```

Exemplo:
- `hello-app-engine.mcs-demo.svc.clusterset.local`

## 🔍 Verificação

```bash
# Ver ServiceExports
kubectl get serviceexport -n mcs-demo

# Ver detalhes
kubectl describe serviceexport hello-app-engine -n mcs-demo

# Verificar DNS (de dentro de um pod)
nslookup hello-app-engine.mcs-demo.svc.clusterset.local
```

## 📚 Referências

- [Google Cloud - Multi-cluster Services](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [ServiceExport - Registering a Service for export](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services#registering_a_service_for_export)
