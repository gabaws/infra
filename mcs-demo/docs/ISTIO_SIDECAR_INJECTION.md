# Injeção do Sidecar Istio no ASM

## 📋 Configuração

Para que o Multi-cluster Services funcione corretamente com o Anthos Service Mesh (ASM), os pods precisam ter o sidecar do Istio injetado automaticamente.

## ✅ Configuração Aplicada

### 1. Labels no Namespace

Os namespaces foram configurados com labels para habilitar a injeção automática:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mcs-demo
  labels:
    name: mcs-demo
    istio-injection: enabled          # Método tradicional
    istio.io/rev: asm-managed         # Revisão específica do ASM
```

### 2. Anotações nos Pods

Os deployments também têm anotações explícitas para garantir a injeção:

```yaml
template:
  metadata:
    annotations:
      sidecar.istio.io/inject: "true"
```

## 🔍 Verificar Injeção do Sidecar

### Verificar se o sidecar foi injetado

```bash
# Verificar pods (deve mostrar 2/2 containers: app + istio-proxy)
kubectl get pods -n mcs-demo

# Ver detalhes de um pod específico
kubectl describe pod <pod-name> -n mcs-demo

# Ver containers no pod
kubectl get pod <pod-name> -n mcs-demo -o jsonpath='{.spec.containers[*].name}'
```

**Resultado esperado**: `hello-server istio-proxy`

### Verificar logs do sidecar

```bash
# Logs do istio-proxy
kubectl logs <pod-name> -n mcs-demo -c istio-proxy

# Logs da aplicação
kubectl logs <pod-name> -n mcs-demo -c hello-server
```

## 🎯 Como Funciona

### ASM com MANAGEMENT_AUTOMATIC

Quando o ASM está configurado com `MANAGEMENT_AUTOMATIC` (como no nosso caso), o Google gerencia automaticamente:

1. **Istiod (Control Plane)**: Instalado e gerenciado automaticamente
2. **Sidecar Injection**: Habilitado via labels/annotations
3. **Configuração**: Aplicada automaticamente via webhooks

### Métodos de Injeção

1. **Label no Namespace** (Recomendado):
   ```yaml
   labels:
     istio-injection: enabled
     istio.io/rev: asm-managed
   ```

2. **Anotação no Pod**:
   ```yaml
   annotations:
     sidecar.istio.io/inject: "true"
   ```

3. **Configuração Global** (via IstioOperator - não aplicável ao ASM gerenciado)

## ⚠️ Troubleshooting

### Sidecar não está sendo injetado

1. **Verificar labels do namespace**:
   ```bash
   kubectl get namespace mcs-demo -o yaml | grep -A 5 labels
   ```

2. **Verificar se o ASM está ativo**:
   ```bash
   gcloud container fleet mesh describe --project=infra-474223
   ```

3. **Verificar webhook de injeção**:
   ```bash
   kubectl get mutatingwebhookconfigurations | grep istio
   ```

4. **Verificar eventos do pod**:
   ```bash
   kubectl describe pod <pod-name> -n mcs-demo | grep -A 10 Events
   ```

### Forçar injeção manual (se necessário)

Se a injeção automática não funcionar, você pode injetar manualmente:

```bash
# Instalar istioctl (se necessário)
curl -L https://istio.io/downloadIstio | sh -

# Injetar sidecar manualmente
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

**Nota**: Com ASM gerenciado, isso geralmente não é necessário.

## 📚 Referências

- [ASM Sidecar Injection](https://cloud.google.com/service-mesh/docs/managed/sidecar-injection)
- [Istio Sidecar Injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
- [ASM Automatic Management](https://cloud.google.com/service-mesh/docs/managed/overview)
