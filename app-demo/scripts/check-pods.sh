#!/bin/bash

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "📋 Verificando pods em ambos os clusters..."
echo ""

echo "🔵 Cluster APP-ENGINE ($APP_ENGINE_CTX):"
echo "----------------------------------------"
kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX 2>&1 || echo "❌ Erro ao conectar ao cluster app-engine"
echo ""

echo "🟢 Cluster MASTER-ENGINE ($MASTER_ENGINE_CTX):"
echo "----------------------------------------"
kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX 2>&1 || echo "❌ Erro ao conectar ao cluster master-engine"
echo ""

echo "📋 Contexto atual do kubectl:"
kubectl config current-context
echo ""

echo "💡 Para mudar de contexto, use:"
echo "   kubectl config use-context $APP_ENGINE_CTX    # Para app-engine"
echo "   kubectl config use-context $MASTER_ENGINE_CTX # Para master-engine"
echo ""
echo "💡 Ou use --context nos comandos:"
echo "   kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX"
echo "   kubectl exec -n mcs-demo -it <pod-name> --context=$APP_ENGINE_CTX -- /bin/bash"
