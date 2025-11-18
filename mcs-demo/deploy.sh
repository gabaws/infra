#!/bin/bash

# Script para fazer deploy das aplicações Multi-cluster Services
# Seguindo a documentação: https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

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

# Deploy no app-engine
echo "📦 Deployando aplicação no cluster $APP_ENGINE_CLUSTER..."
cd app-engine
kubectl apply -k . --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}
cd ..

echo ""
echo "📦 Deployando aplicação no cluster $MASTER_ENGINE_CLUSTER..."
cd master-engine
kubectl apply -k . --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}
cd ..

echo ""
echo "⏳ Aguardando pods ficarem prontos..."
sleep 15

echo ""
echo "📊 Status dos pods (deve mostrar 2/2 containers: app + istio-proxy):"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}

echo ""
echo "📊 Status dos MultiClusterServices:"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get multiclusterservice -n mcs-demo --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get multiclusterservice -n mcs-demo --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}

echo ""
echo "🔍 Verificando injeção do sidecar Istio..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER (deve mostrar 2/2 containers):"
kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER} -o wide

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER (deve mostrar 2/2 containers):"
kubectl get pods -n mcs-demo --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER} -o wide

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "💡 Se os pods mostrarem 1/2 containers, o sidecar ainda está sendo injetado. Aguarde alguns segundos."
echo ""
echo "🧪 Para testar a comunicação entre clusters, execute:"
echo ""
echo "  # Teste de app-engine para master-engine:"
echo "  kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \\"
echo "    --context=gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER} \\"
echo "    -- curl http://hello-master-engine.mcs-demo.svc.clusterset.local"
echo ""
echo "  # Teste de master-engine para app-engine:"
echo "  kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -n mcs-demo \\"
echo "    --context=gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER} \\"
echo "    -- curl http://hello-app-engine.mcs-demo.svc.clusterset.local"
echo ""
