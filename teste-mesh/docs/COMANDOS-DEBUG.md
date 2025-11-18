# Comandos para Debug - Eventos e Logs de Pods

## 📋 Ver Eventos de um Pod Específico

### Opção 1: Filtrar eventos por nome do pod
```bash
# Ver eventos relacionados a um pod específico
kubectl get events -n <namespace> --field-selector involvedObject.name=<nome-do-pod>

# Exemplo prático:
kubectl get events -n dev-get-test \
  --field-selector involvedObject.name=dev-get-test-5c5bc674d7-9g75b \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Opção 2: Filtrar eventos por tipo de objeto (Pod)
```bash
# Ver todos os eventos de pods no namespace
kubectl get events -n <namespace> --field-selector involvedObject.kind=Pod

# Exemplo:
kubectl get events -n dev-get-test \
  --field-selector involvedObject.kind=Pod \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Opção 3: Filtrar eventos por label do pod
```bash
# Ver eventos de pods com uma label específica
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# Ou usar describe do pod (mostra eventos relacionados)
kubectl describe pod <nome-do-pod> -n <namespace>
```

### Opção 4: Usar describe (mais completo)
```bash
# Describe mostra eventos relacionados ao pod no final
kubectl describe pod <nome-do-pod> -n <namespace> --context=<contexto>

# Exemplo:
kubectl describe pod dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

## 📜 Ver Logs de um Pod

### Logs do Container Principal
```bash
# Logs do container principal do pod
kubectl logs <nome-do-pod> -n <namespace> --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs do Sidecar Istio
```bash
# Logs do sidecar Istio (istio-proxy)
kubectl logs <nome-do-pod> -n <namespace> -c istio-proxy --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  -c istio-proxy \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs de Todos os Containers
```bash
# Logs de todos os containers do pod
kubectl logs <nome-do-pod> -n <namespace> --all-containers=true --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --all-containers=true \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs com Follow (streaming em tempo real)
```bash
# Seguir logs em tempo real (como tail -f)
kubectl logs -f <nome-do-pod> -n <namespace> --context=<contexto>

# Exemplo:
kubectl logs -f dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs das Últimas N Linhas
```bash
# Ver apenas as últimas 50 linhas
kubectl logs <nome-do-pod> -n <namespace> --tail=50 --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --tail=50 \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs com Timestamps
```bash
# Logs com timestamps
kubectl logs <nome-do-pod> -n <namespace> --timestamps --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --timestamps \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Logs de um Período Específico
```bash
# Logs desde um tempo específico
kubectl logs <nome-do-pod> -n <namespace> --since=10m --context=<contexto>
kubectl logs <nome-do-pod> -n <namespace> --since=1h --context=<contexto>

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --since=10m \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

## 🔍 Comandos Úteis Combinados

### Ver Pod + Eventos + Logs (Tudo de uma vez)
```bash
# 1. Obter nome do pod
POD_NAME=$(kubectl get pod -l app=dev-get-test -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

# 2. Ver eventos do pod
kubectl get events -n dev-get-test \
  --field-selector involvedObject.name=$POD_NAME \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# 3. Ver logs do container principal
kubectl logs $POD_NAME -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# 4. Ver logs do sidecar Istio
kubectl logs $POD_NAME -n dev-get-test -c istio-proxy \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# 5. Ver describe completo (inclui eventos)
kubectl describe pod $POD_NAME -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

### Ver Logs de Múltiplos Pods (por label)
```bash
# Logs de todos os pods com uma label específica
kubectl logs -l app=dev-get-test -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# Com follow (streaming)
kubectl logs -f -l app=dev-get-test -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

## 🎯 Exemplos Práticos para Este Projeto

### Cluster A (dev-dis-test)
```bash
# Obter pod
POD_NAME=$(kubectl get pod -l app=dev-dis-test -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

# Eventos
kubectl get events -n dev-dis-test \
  --field-selector involvedObject.name=$POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Logs principal
kubectl logs $POD_NAME -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Logs Istio
kubectl logs $POD_NAME -n dev-dis-test -c istio-proxy \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine
```

### Cluster B (dev-get-test)
```bash
# Obter pod
POD_NAME=$(kubectl get pod -l app=dev-get-test -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

# Eventos
kubectl get events -n dev-get-test \
  --field-selector involvedObject.name=$POD_NAME \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# Logs principal
kubectl logs $POD_NAME -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine

# Logs Istio
kubectl logs $POD_NAME -n dev-get-test -c istio-proxy \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

## 📊 Ver Todos os Containers de um Pod

```bash
# Listar containers do pod
kubectl get pod <nome-do-pod> -n <namespace> \
  -o jsonpath='{.spec.containers[*].name}'

# Exemplo:
kubectl get pod dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine \
  -o jsonpath='{.spec.containers[*].name}'

# Resultado esperado: dev-get-test istio-proxy
```

## 🔧 Troubleshooting Avançado

### Ver Logs de Container de Init
```bash
kubectl logs <nome-do-pod> -n <namespace> -c <nome-do-init-container>
```

### Ver Logs de Container Anterior (se o pod reiniciou)
```bash
kubectl logs <nome-do-pod> -n <namespace> --previous
```

### Ver Logs com Filtro (grep)
```bash
# Filtrar logs por palavra-chave
kubectl logs <nome-do-pod> -n <namespace> | grep "ERROR"

# Exemplo:
kubectl logs dev-get-test-5c5bc674d7-9g75b -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine \
  | grep -i error
```

## 💡 Dicas

1. **kubectl describe pod** é a forma mais completa - mostra eventos no final
2. **kubectl get events** com `--field-selector` é mais rápido para filtrar
3. Use `-f` (follow) para monitorar logs em tempo real
4. Use `--tail` para ver apenas as últimas linhas
5. Use `--since` para ver logs de um período específico
6. Para sidecar Istio, sempre use `-c istio-proxy`
