#!/bin/bash

# Script para forçar rollout dos deployments após mudança de imagem

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔄 Forçando rollout dos deployments..."
echo ""

echo "📦 Deletando pods antigos no cluster $APP_ENGINE_CLUSTER..."
kubectl delete pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine --grace-period=0 --force 2>/dev/null || true

echo ""
echo "📦 Deletando pods antigos no cluster $MASTER_ENGINE_CLUSTER..."
kubectl delete pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine --grace-period=0 --force 2>/dev/null || true

echo ""
echo "⏳ Aguardando novos pods ficarem prontos..."
sleep 10

echo ""
echo "📊 Status dos pods:"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine

echo ""
echo "✅ Rollout forçado concluído!"
echo ""
echo "💡 Aguarde alguns segundos para os pods ficarem prontos (2/2 containers)"
