#!/bin/bash

# Script para verificar métricas do Istio no Cloud Monitoring

set +e

PROJECT_ID="infra-474223"

echo "📊 Verificando Métricas do Istio no Cloud Monitoring"
echo ""

echo "ℹ️  No ASM gerenciado (MANAGEMENT_AUTOMATIC), métricas são enviadas automaticamente"
echo "   para o Cloud Monitoring do GCP, não para Prometheus local."
echo ""

echo "1️⃣ Verificando métricas de requisições HTTP..."
echo ""
gcloud monitoring time-series list \
  --filter='metric.type="istio.io/service/request_count"' \
  --project=$PROJECT_ID \
  --limit=5 \
  2>/dev/null || echo "  ⚠️  Não foi possível acessar métricas. Verifique permissões."

echo ""
echo "2️⃣ Verificando métricas de latência..."
echo ""
gcloud monitoring time-series list \
  --filter='metric.type="istio.io/service/request_duration"' \
  --project=$PROJECT_ID \
  --limit=5 \
  2>/dev/null || echo "  ⚠️  Não foi possível acessar métricas. Verifique permissões."

echo ""
echo "3️⃣ Verificando métricas de erros..."
echo ""
gcloud monitoring time-series list \
  --filter='metric.type="istio.io/service/request_count" AND metric.labels.response_code=~"5.."' \
  --project=$PROJECT_ID \
  --limit=5 \
  2>/dev/null || echo "  ⚠️  Não foi possível acessar métricas. Verifique permissões."

echo ""
echo "✅ Verificação concluída!"
echo ""
echo "💡 Para visualizar métricas no console:"
echo "   https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"
echo ""
echo "💡 Para consultar métricas via API:"
echo "   gcloud monitoring time-series list --filter='metric.type=\"istio.io/service/request_count\"' --project=$PROJECT_ID"
