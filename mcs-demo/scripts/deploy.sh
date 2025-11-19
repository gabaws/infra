#!/bin/bash

# Script para fazer deploy das aplicações Multi-cluster Services

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🚀 Deploy Multi-cluster Services Demo"
echo ""

# Verificar se gcloud está instalado
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud não está instalado. Por favor, instale o Google Cloud SDK."
    exit 1
fi

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não está instalado. Por favor, instale o kubectl."
    exit 1
fi

echo "📋 Configurando projeto..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

echo "🔗 Conectando aos clusters..."
echo ""

# Conectar ao cluster app-engine
echo "Conectando ao cluster $APP_ENGINE_CLUSTER..."
gcloud container clusters get-credentials $APP_ENGINE_CLUSTER \
  --location=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

# Conectar ao cluster master-engine
echo "Conectando ao cluster $MASTER_ENGINE_CLUSTER..."
gcloud container clusters get-credentials $MASTER_ENGINE_CLUSTER \
  --location=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo ""
echo "✅ Clusters conectados!"
echo ""

# Obter diretório base do projeto (mcs-demo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Deploy no app-engine
echo "📦 Deployando aplicação no cluster $APP_ENGINE_CLUSTER..."
cd "$BASE_DIR/app-engine"
kubectl apply -k . --context=$APP_ENGINE_CTX

echo ""
echo "📦 Deployando aplicação no cluster $MASTER_ENGINE_CLUSTER..."
cd "$BASE_DIR/master-engine"
kubectl apply -k . --context=$MASTER_ENGINE_CTX

echo ""
echo "⏳ Aguardando pods ficarem prontos..."
sleep 20

echo ""
echo "📊 Status dos pods (deve mostrar 2/2 containers: app + istio-proxy):"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "📊 Status dos ServiceExports:"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get serviceexport -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceexport -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "⏳ Aguarde alguns minutos para a propagação dos serviços entre clusters."
echo ""
echo "🧪 Para testar a comunicação entre clusters, execute:"
echo "   ./scripts/test-communication.sh"
echo ""
