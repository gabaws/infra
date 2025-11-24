#!/bin/bash

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🧪 Teste de Comunicação ASM Multi-cluster (sem MCS)"
echo ""

echo "📋 Verificando status dos pods..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "📋 Verificando ServiceEntry..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get serviceentry -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceentry -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "🧪 Teste 1: De $APP_ENGINE_CLUSTER para $MASTER_ENGINE_CLUSTER"
echo ""

APP_POD=$(kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$APP_POD" ]; then
    echo "❌ Nenhum pod hello-app-engine encontrado no cluster $APP_ENGINE_CLUSTER"
    exit 1
fi

APP_POD_STATUS=$(kubectl get pod $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.status.phase}' 2>/dev/null)
APP_POD_READY=$(kubectl get pod $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.status.containerStatuses[?(@.name=="hello-server")].ready}' 2>/dev/null)

if [ "$APP_POD_STATUS" != "Running" ] || [ "$APP_POD_READY" != "true" ]; then
    echo "❌ Pod $APP_POD não está pronto para execução"
    echo "   Status: $APP_POD_STATUS"
    echo "   Ready: $APP_POD_READY"
    exit 1
fi

echo "📦 Usando pod: $APP_POD"
echo "🌐 Testando comunicação para hello-master-engine.mcs-demo.global..."
echo ""

# Usa o formato .global para ASM multi-cluster
RESULT=$(kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c hello-server -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-master-engine.mcs-demo.global:80 2>&1)

HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESULT" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ] || echo "$BODY" | grep -q "Hello from master-engine"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "HTTP Status: $HTTP_CODE"
    echo "Resposta: $BODY"
else
    echo "❌ Falha na comunicação"
    echo "Resposta completa: $RESULT"
    echo ""
    echo "🔍 Diagnóstico adicional:"
    echo "Testando DNS..."
    kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c hello-server -- \
      nslookup hello-master-engine.mcs-demo.global 2>&1 || true
fi

echo ""
echo ""
echo "🧪 Teste 2: De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER"
echo ""

MASTER_POD=$(kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MASTER_POD" ]; then
    echo "❌ Nenhum pod hello-master-engine encontrado no cluster $MASTER_ENGINE_CLUSTER"
    exit 1
fi

MASTER_POD_STATUS=$(kubectl get pod $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.status.phase}' 2>/dev/null)
MASTER_POD_READY=$(kubectl get pod $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.status.containerStatuses[?(@.name=="hello-server")].ready}' 2>/dev/null)

if [ "$MASTER_POD_STATUS" != "Running" ] || [ "$MASTER_POD_READY" != "true" ]; then
    echo "❌ Pod $MASTER_POD não está pronto para execução"
    echo "   Status: $MASTER_POD_STATUS"
    echo "   Ready: $MASTER_POD_READY"
    exit 1
fi

echo "📦 Usando pod: $MASTER_POD"
echo "🌐 Testando comunicação para hello-app-engine.mcs-demo.global..."
echo ""

RESULT=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-app-engine.mcs-demo.global:80 2>&1)

HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESULT" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ] || echo "$BODY" | grep -q "Hello from app-engine"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "HTTP Status: $HTTP_CODE"
    echo "Resposta: $BODY"
else
    echo "❌ Falha na comunicação"
    echo "Resposta completa: $RESULT"
    echo ""
    echo "🔍 Diagnóstico adicional:"
    echo "Testando DNS..."
    kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
      nslookup hello-app-engine.mcs-demo.global 2>&1 || true
fi

echo ""
echo "✅ Testes concluídos!"
echo ""

