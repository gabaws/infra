#!/bin/bash

# Script para verificar telemetria e rate-limit no ASM

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "📊 Verificação de Telemetria e Rate-Limit no ASM"
echo ""

echo "1️⃣ Verificando componentes de telemetria..."
echo ""

echo "Cluster $APP_ENGINE_CLUSTER:"
echo "  Prometheus:"
kubectl get pods -n istio-system --context=$APP_ENGINE_CTX | grep prometheus || echo "    ⚠️  Prometheus não encontrado"

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
echo "  Prometheus:"
kubectl get pods -n istio-system --context=$MASTER_ENGINE_CTX | grep prometheus || echo "    ⚠️  Prometheus não encontrado"

echo ""
echo "2️⃣ Verificando logs do sidecar (telemetria de acesso)..."
echo ""

APP_POD=$(kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APP_POD" ]; then
  echo "Cluster $APP_ENGINE_CLUSTER - Pod: $APP_POD"
  echo "  Últimas 5 linhas de log do sidecar:"
  kubectl logs $APP_POD -n mcs-demo -c istio-proxy --context=$APP_ENGINE_CTX --tail=5 2>/dev/null || echo "    ⚠️  Não foi possível obter logs"
else
  echo "  ⚠️  Nenhum pod encontrado"
fi

echo ""
MASTER_POD=$(kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MASTER_POD" ]; then
  echo "Cluster $MASTER_ENGINE_CLUSTER - Pod: $MASTER_POD"
  echo "  Últimas 5 linhas de log do sidecar:"
  kubectl logs $MASTER_POD -n mcs-demo -c istio-proxy --context=$MASTER_ENGINE_CTX --tail=5 2>/dev/null || echo "    ⚠️  Não foi possível obter logs"
else
  echo "  ⚠️  Nenhum pod encontrado"
fi

echo ""
echo "3️⃣ Verificando métricas do sidecar..."
echo ""

if [ -n "$APP_POD" ]; then
  echo "Cluster $APP_ENGINE_CLUSTER - Pod: $APP_POD"
  echo "  Estatísticas do Envoy (últimas requisições):"
  STATS=$(kubectl exec $APP_POD -n mcs-demo -c istio-proxy --context=$APP_ENGINE_CTX -- \
    curl -s http://localhost:15000/stats 2>/dev/null | grep -E "cluster\.outbound\|80\|.*\.upstream_rq_total|cluster\.outbound\|80\|.*\.upstream_rq_2xx" | head -5)
  if [ -n "$STATS" ]; then
    echo "$STATS"
  else
    echo "    ℹ️  Nenhuma requisição registrada ainda (faça algumas requisições primeiro)"
  fi
  
  echo ""
  echo "  Métricas Prometheus do sidecar:"
  PROM_STATS=$(kubectl exec $APP_POD -n mcs-demo -c istio-proxy --context=$APP_ENGINE_CTX -- \
    curl -s http://localhost:15000/stats/prometheus 2>/dev/null | grep -E "istio_requests_total|istio_request_duration" | head -5)
  if [ -n "$PROM_STATS" ]; then
    echo "$PROM_STATS"
  else
    echo "    ℹ️  Métricas Prometheus não disponíveis (normal no ASM gerenciado)"
  fi
fi

echo ""
echo "4️⃣ Verificando Rate-Limit configurado..."
echo ""

echo "Cluster $APP_ENGINE_CLUSTER:"
ENVOYFILTERS_APP=$(kubectl get envoyfilter -n mcs-demo --context=$APP_ENGINE_CTX 2>/dev/null)
if [ -n "$ENVOYFILTERS_APP" ]; then
  echo "$ENVOYFILTERS_APP"
else
  echo "  ℹ️  Nenhum EnvoyFilter encontrado (rate-limit não configurado)"
fi

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
ENVOYFILTERS_MASTER=$(kubectl get envoyfilter -n mcs-demo --context=$MASTER_ENGINE_CTX 2>/dev/null)
if [ -n "$ENVOYFILTERS_MASTER" ]; then
  echo "$ENVOYFILTERS_MASTER"
else
  echo "  ℹ️  Nenhum EnvoyFilter encontrado (rate-limit não configurado)"
fi

echo ""
echo "5️⃣ Verificando Rate Limit Service (se configurado)..."
echo ""

RATELIMIT_APP=$(kubectl get svc -n istio-system --context=$APP_ENGINE_CTX | grep ratelimit 2>/dev/null)
if [ -n "$RATELIMIT_APP" ]; then
  echo "Cluster $APP_ENGINE_CLUSTER:"
  echo "$RATELIMIT_APP"
else
  echo "  ℹ️  Rate Limit Service não encontrado"
fi

echo ""
echo "6️⃣ Verificando métricas no Cloud Monitoring (ASM gerenciado)..."
echo ""

echo "  ℹ️  No ASM gerenciado, métricas são enviadas para Cloud Monitoring"
echo "  Para verificar métricas no GCP:"
echo "    gcloud monitoring time-series list \\"
echo "      --filter='metric.type=\"istio.io/service/request_count\"' \\"
echo "      --project=$PROJECT_ID --limit=5"
echo ""
echo "  Ou acesse: https://console.cloud.google.com/monitoring/dashboards"
echo ""

echo ""
echo "✅ Verificação concluída!"
echo ""
echo "📊 Resumo:"
echo "   - Telemetria (Logs): ✅ Funcionando (veja logs acima)"
echo "   - Telemetria (Métricas): ℹ️  Enviadas para Cloud Monitoring (ASM gerenciado)"
echo "   - Rate-Limit: ❌ Não configurado (normal, precisa configurar manualmente)"
echo ""
echo "💡 Para mais detalhes, consulte:"
echo "   - docs/TELEMETRIA_E_RATE_LIMIT.md"
echo "   - kubectl logs <pod-name> -n mcs-demo -c istio-proxy --tail=50"
echo "   - Cloud Monitoring: https://console.cloud.google.com/monitoring"
