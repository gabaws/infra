#!/bin/bash

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔍 Obtendo IPs dos East-West Gateways..."

# Obtém IP do East-West Gateway do cluster app-engine
APP_ENGINE_GW_IP=$(kubectl get svc -n istio-system --context=$APP_ENGINE_CTX istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

# Obtém IP do East-West Gateway do cluster master-engine
MASTER_ENGINE_GW_IP=$(kubectl get svc -n istio-system --context=$MASTER_ENGINE_CTX istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$APP_ENGINE_GW_IP" ]; then
    echo "⚠️  AVISO: Não foi possível obter o IP do East-West Gateway do cluster app-engine"
    echo "   Verifique se o gateway está instalado: kubectl get svc -n istio-system --context=$APP_ENGINE_CTX"
    APP_ENGINE_GW_IP="<APP_ENGINE_GW_IP>"
fi

if [ -z "$MASTER_ENGINE_GW_IP" ]; then
    echo "⚠️  AVISO: Não foi possível obter o IP do East-West Gateway do cluster master-engine"
    echo "   Verifique se o gateway está instalado: kubectl get svc -n istio-system --context=$MASTER_ENGINE_CTX"
    MASTER_ENGINE_GW_IP="<MASTER_ENGINE_GW_IP>"
fi

echo ""
echo "📊 IPs obtidos:"
echo "   app-engine East-West Gateway: $APP_ENGINE_GW_IP"
echo "   master-engine East-West Gateway: $MASTER_ENGINE_GW_IP"
echo ""

# Exporta variáveis para uso em outros scripts
export APP_ENGINE_GW_IP
export MASTER_ENGINE_GW_IP

