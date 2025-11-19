#!/bin/bash

# Script para aumentar o max_node_count dos node pools para resolver problemas de CPU insuficiente

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_NODE_POOL="${APP_ENGINE_CLUSTER}-node-pool"
MASTER_ENGINE_NODE_POOL="${MASTER_ENGINE_CLUSTER}-node-pool"

NEW_MAX_NODES=6

echo "🔧 Ajustando autoscaling dos node pools"
echo ""

echo "📋 Cluster: $APP_ENGINE_CLUSTER"
echo "   Node Pool: $APP_ENGINE_NODE_POOL"
echo "   Aumentando max_node_count para $NEW_MAX_NODES..."
gcloud container node-pools update $APP_ENGINE_NODE_POOL \
  --cluster=$APP_ENGINE_CLUSTER \
  --zone=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=$NEW_MAX_NODES \
  --quiet

echo ""
echo "📋 Cluster: $MASTER_ENGINE_CLUSTER"
echo "   Node Pool: $MASTER_ENGINE_NODE_POOL"
echo "   Aumentando max_node_count para $NEW_MAX_NODES..."
gcloud container node-pools update $MASTER_ENGINE_NODE_POOL \
  --cluster=$MASTER_ENGINE_CLUSTER \
  --zone=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=$NEW_MAX_NODES \
  --quiet

echo ""
echo "✅ Autoscaling atualizado com sucesso!"
echo ""
echo "💡 O cluster-autoscaler agora pode adicionar até $NEW_MAX_NODES nós por cluster"
echo "💡 Os pods pendentes devem ser agendados automaticamente quando novos nós forem criados"
echo ""
echo "📊 Para verificar o status dos pods:"
echo "   kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
echo "   kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"
