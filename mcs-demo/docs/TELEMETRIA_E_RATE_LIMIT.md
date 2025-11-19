# Telemetria e Rate-Limit no Anthos Service Mesh (ASM)

## 📊 Telemetria

### ✅ Telemetria já vem habilitada por padrão

O ASM (Anthos Service Mesh) coleta automaticamente métricas, logs e traces de todos os serviços gerenciados pelo Istio, **sem necessidade de configuração adicional**.

### O que é coletado automaticamente:

1. **Métricas Prometheus**:
   - Requisições HTTP/gRPC (requests, responses, latência)
   - Conexões TCP
   - Erros e timeouts
   - Throughput

2. **Logs do Sidecar**:
   - Logs de acesso (access logs)
   - Logs de erro do Envoy

3. **Traces distribuídos** (se configurado):
   - Traces entre serviços

### Como verificar telemetria:

#### 1. Verificar métricas do Prometheus

```bash
# Verificar se o Prometheus está coletando métricas
kubectl get pods -n istio-system --context=<contexto> | grep prometheus

# Acessar métricas de um pod específico
kubectl port-forward -n istio-system svc/prometheus 9090:9090 --context=<contexto>
# Acessar: http://localhost:9090
```

#### 2. Verificar métricas via kubectl

```bash
# Métricas de requisições HTTP
kubectl exec -n istio-system <istiod-pod> --context=<contexto> -- \
  curl -s http://localhost:15014/metrics | grep istio_requests_total

# Métricas de latência
kubectl exec -n istio-system <istiod-pod> --context=<contexto> -- \
  curl -s http://localhost:15014/metrics | grep istio_request_duration
```

#### 3. Verificar logs do sidecar

```bash
# Logs de acesso de um pod específico
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> --tail=50

# Ver logs de requisições HTTP
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> | grep "GET\|POST"

# Ver logs de erros
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> | grep -i error
```

#### 4. Verificar métricas no Cloud Monitoring (GCP)

```bash
# Verificar se métricas estão sendo enviadas para Cloud Monitoring
gcloud monitoring time-series list \
  --filter='metric.type="istio.io/service/request_count"' \
  --project=<project-id>
```

#### 5. Consultar métricas via PromQL

```bash
# Total de requisições por serviço
kubectl exec -n istio-system <prometheus-pod> --context=<contexto> -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=istio_requests_total' | jq

# Taxa de erro por serviço
kubectl exec -n istio-system <prometheus-pod> --context=<contexto> -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=rate(istio_requests_total{response_code=~"5.."}[5m])' | jq
```

### Métricas importantes coletadas:

- `istio_requests_total`: Total de requisições
- `istio_request_duration_seconds`: Latência das requisições
- `istio_request_bytes`: Bytes enviados
- `istio_response_bytes`: Bytes recebidos
- `istio_tcp_sent_bytes_total`: Bytes TCP enviados
- `istio_tcp_received_bytes_total`: Bytes TCP recebidos

## 🚦 Rate-Limit

### ⚠️ Rate-Limit NÃO vem habilitado por padrão

O rate-limit precisa ser configurado manualmente usando **EnvoyFilter** ou **Envoy Rate Limit Service**.

### Opções para implementar Rate-Limit:

#### Opção 1: EnvoyFilter (Local Rate-Limit)

Rate-limit simples baseado em configuração local do Envoy:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: local-rate-limit
  namespace: mcs-demo
spec:
  workloadSelector:
    labels:
      app: hello-app-engine
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          stat_prefix: http_local_rate_limiter
          token_bucket:
            max_tokens: 10
            tokens_per_fill: 10
            fill_interval: 60s
```

#### Opção 2: Envoy Rate Limit Service (Global Rate-Limit)

Rate-limit mais avançado usando serviço externo:

1. **Deploy do Rate Limit Service**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratelimit
  namespace: istio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratelimit
  template:
    metadata:
      labels:
        app: ratelimit
    spec:
      containers:
      - name: ratelimit
        image: envoyproxy/ratelimit:master
        ports:
        - containerPort: 8080
        - containerPort: 6070
        env:
        - name: LOG_LEVEL
          value: debug
        - name: USE_STATSD
          value: "false"
        - name: RUNTIME_ROOT
          value: /data
        - name: RUNTIME_SUBDIRECTORY
          value: ratelimit
        volumeMounts:
        - name: config-volume
          mountPath: /data/ratelimit/config
      volumes:
      - name: config-volume
        configMap:
          name: ratelimit-config
---
apiVersion: v1
kind: Service
metadata:
  name: ratelimit
  namespace: istio-system
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  - port: 6070
    targetPort: 6070
    name: grpc
  selector:
    app: ratelimit
```

2. **Configuração do Rate Limit**:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: filter-ratelimit
  namespace: mcs-demo
spec:
  workloadSelector:
    labels:
      app: hello-app-engine
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
          domain: mcs-demo
          failure_mode_deny: true
          rate_limit_service:
            grpc_service:
              envoy_grpc:
                cluster_name: outbound|8080||ratelimit.istio-system.svc.cluster.local
            transport_api_version: V3
```

### Como validar Rate-Limit:

#### 1. Verificar se o EnvoyFilter foi aplicado

```bash
# Verificar EnvoyFilters
kubectl get envoyfilter -n mcs-demo --context=<contexto>

# Ver detalhes
kubectl describe envoyfilter local-rate-limit -n mcs-demo --context=<contexto>
```

#### 2. Verificar configuração no sidecar

```bash
# Ver configuração do Envoy no sidecar
kubectl exec <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> -- \
  curl -s http://localhost:15000/config_dump | jq '.configs[2].dynamic_listeners[] | select(.name | contains("0.0.0.0_80"))'
```

#### 3. Testar rate-limit

```bash
# Fazer múltiplas requisições rapidamente
for i in {1..20}; do
  curl -s http://hello-app-engine.mcs-demo.svc.clusterset.local:80
  echo "Requisição $i"
done

# Verificar se algumas requisições foram bloqueadas (HTTP 429)
```

#### 4. Verificar logs do rate-limit

```bash
# Logs do sidecar mostrando rate-limit
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> | grep -i "rate.limit\|429"

# Se usando Rate Limit Service
kubectl logs -n istio-system -l app=ratelimit --context=<contexto>
```

#### 5. Verificar métricas de rate-limit

```bash
# Métricas de requisições bloqueadas
kubectl exec <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> -- \
  curl -s http://localhost:15000/stats | grep rate_limit

# Ver estatísticas do rate-limit
kubectl exec <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> -- \
  curl -s http://localhost:15000/stats/prometheus | grep rate_limit
```

## 📋 Resumo

| Funcionalidade | Status Padrão | Como Validar |
|---------------|---------------|--------------|
| **Telemetria (Métricas)** | ✅ Habilitada | `kubectl logs -c istio-proxy`, Prometheus |
| **Telemetria (Logs)** | ✅ Habilitada | `kubectl logs -c istio-proxy` |
| **Telemetria (Traces)** | ⚠️ Opcional | Configurar Jaeger/Zipkin |
| **Rate-Limit** | ❌ Desabilitado | Configurar EnvoyFilter ou Rate Limit Service |

## 🔍 Comandos Rápidos de Validação

```bash
# 1. Verificar se telemetria está ativa (métricas)
kubectl get pods -n istio-system | grep prometheus

# 2. Ver logs do sidecar (telemetria de acesso)
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --tail=20

# 3. Verificar se rate-limit está configurado
kubectl get envoyfilter -n mcs-demo

# 4. Testar rate-limit (se configurado)
for i in {1..15}; do curl -s http://hello-app-engine.mcs-demo.svc.clusterset.local:80; done

# 5. Ver métricas do Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090
# Acessar: http://localhost:9090
```

## 📚 Referências

- [ASM Observability](https://cloud.google.com/service-mesh/docs/observability)
- [Istio Telemetry](https://istio.io/latest/docs/tasks/observability/)
- [Envoy Rate Limiting](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_features/rate_limit)
- [ASM Rate Limiting](https://cloud.google.com/service-mesh/docs/rate-limiting)
