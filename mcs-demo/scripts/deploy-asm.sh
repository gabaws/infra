#!/bin/bash

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🚀 Deploy ASM Multi-cluster Demo (sem MCS)"
echo ""

if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud não está instalado. Por favor, instale o Google Cloud SDK."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não está instalado. Por favor, instale o kubectl."
    exit 1
fi

echo "📋 Configurando projeto..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

echo "🔗 Conectando aos clusters..."
echo ""

echo "Conectando ao cluster $APP_ENGINE_CLUSTER..."
gcloud container clusters get-credentials $APP_ENGINE_CLUSTER \
  --location=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo "Conectando ao cluster $MASTER_ENGINE_CLUSTER..."
gcloud container clusters get-credentials $MASTER_ENGINE_CLUSTER \
  --location=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo ""
echo "✅ Clusters conectados!"
echo ""

# Obtém IPs dos East-West Gateways
echo "🔍 Obtendo IPs dos East-West Gateways..."

APP_ENGINE_GW_IP=$(kubectl get svc -n istio-system --context=$APP_ENGINE_CTX istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
MASTER_ENGINE_GW_IP=$(kubectl get svc -n istio-system --context=$MASTER_ENGINE_CTX istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$APP_ENGINE_GW_IP" ]; then
    echo "❌ ERRO: Não foi possível obter o IP do East-West Gateway do cluster app-engine"
    echo "   Verifique se o gateway está instalado:"
    echo "   kubectl get svc -n istio-system --context=$APP_ENGINE_CTX istio-eastwestgateway"
    exit 1
fi

if [ -z "$MASTER_ENGINE_GW_IP" ]; then
    echo "❌ ERRO: Não foi possível obter o IP do East-West Gateway do cluster master-engine"
    echo "   Verifique se o gateway está instalado:"
    echo "   kubectl get svc -n istio-system --context=$MASTER_ENGINE_CTX istio-eastwestgateway"
    exit 1
fi

echo "   ✅ app-engine East-West Gateway: $APP_ENGINE_GW_IP"
echo "   ✅ master-engine East-West Gateway: $MASTER_ENGINE_GW_IP"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cria diretório temporário para manifestos atualizados
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 Preparando manifestos para deploy..."
echo ""

# Copia arquivos do app-engine e substitui placeholders
mkdir -p "$TEMP_DIR/app-engine"
cp -r "$BASE_DIR/app-engine"/* "$TEMP_DIR/app-engine/"

# Substitui placeholder no ServiceEntry do app-engine
sed -i.bak "s/PLACEHOLDER_MASTER_ENGINE_GW_IP/$MASTER_ENGINE_GW_IP/g" "$TEMP_DIR/app-engine/serviceentry-master.yaml"
rm "$TEMP_DIR/app-engine/serviceentry-master.yaml.bak" 2>/dev/null || true

# Copia arquivos do master-engine e substitui placeholders
mkdir -p "$TEMP_DIR/master-engine"
cp -r "$BASE_DIR/master-engine"/* "$TEMP_DIR/master-engine/"

# Substitui placeholder no ServiceEntry do master-engine
sed -i.bak "s/PLACEHOLDER_APP_ENGINE_GW_IP/$APP_ENGINE_GW_IP/g" "$TEMP_DIR/master-engine/serviceentry-app.yaml"
rm "$TEMP_DIR/master-engine/serviceentry-app.yaml.bak" 2>/dev/null || true

echo "📦 Deployando aplicação no cluster $APP_ENGINE_CLUSTER..."
cd "$TEMP_DIR/app-engine"
kubectl apply -k . --context=$APP_ENGINE_CTX

echo ""
echo "📦 Deployando aplicação no cluster $MASTER_ENGINE_CLUSTER..."
cd "$TEMP_DIR/master-engine"
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
echo "📊 Status dos ServiceEntry (ASM):"
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get serviceentry -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceentry -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "🧪 Para testar a comunicação entre clusters, execute:"
echo "   ./scripts/test-communication-asm.sh"
echo ""

