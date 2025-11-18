#!/bin/bash

# Script para testar comunicação entre clusters usando Multi-cluster Services

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

echo "🧪 Teste de Comunicação Multi-cluster Services"
echo ""

# Contextos kubectl
APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "📋 Verificando status dos pods..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "📋 Verificando serviços..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get svc -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get svc -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "📋 Verificando MultiClusterServices..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get multiclusterservice -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get multiclusterservice -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "🧪 Teste 1: De $APP_ENGINE_CLUSTER para $MASTER_ENGINE_CLUSTER"
echo ""
kubectl run test-pod-app-engine --image=curlimages/curl:latest --rm -i --restart=Never -n mcs-demo \
  --context=$APP_ENGINE_CTX \
  -- curl -s http://hello-master-engine.mcs-demo.svc.clusterset.local || echo "❌ Falha na comunicação"

echo ""
echo ""
echo "🧪 Teste 2: De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER"
echo ""
kubectl run test-pod-master-engine --image=curlimages/curl:latest --rm -i --restart=Never -n mcs-demo \
  --context=$MASTER_ENGINE_CTX \
  -- curl -s http://hello-app-engine.mcs-demo.svc.clusterset.local || echo "❌ Falha na comunicação"

echo ""
echo "✅ Testes concluídos!"
echo ""
echo "💡 Para mais detalhes, verifique os logs dos pods ou use:"
echo "   kubectl describe multiclusterservice <nome> -n mcs-demo --context=<contexto>"
