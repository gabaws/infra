#!/bin/bash

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🚀 Instalando East-West Gateway para ASM Multi-cluster"
echo ""

if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud não está instalado."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não está instalado."
    exit 1
fi

echo "📋 Configurando projeto..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

echo "🔗 Conectando aos clusters..."
gcloud container clusters get-credentials $APP_ENGINE_CLUSTER \
  --location=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

gcloud container clusters get-credentials $MASTER_ENGINE_CLUSTER \
  --location=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo "✅ Clusters conectados!"
echo ""

# Obtém o Mesh ID (project number)
MESH_ID=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo "📊 Mesh ID (Project Number): $MESH_ID"
echo ""

# Obtém revisões do ASM
echo "🔍 Obtendo revisões do ASM..."
APP_ASM_REV=$(kubectl get deployment -n istio-system -l app=istiod --context=$APP_ENGINE_CTX -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "asm-managed")
MASTER_ASM_REV=$(kubectl get deployment -n istio-system -l app=istiod --context=$MASTER_ENGINE_CTX -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "asm-managed")

if [ -z "$APP_ASM_REV" ] || [ "$APP_ASM_REV" == "null" ]; then
    APP_ASM_REV="asm-managed"
fi

if [ -z "$MASTER_ASM_REV" ] || [ "$MASTER_ASM_REV" == "null" ]; then
    MASTER_ASM_REV="asm-managed"
fi

echo "   app-engine ASM revision: $APP_ASM_REV"
echo "   master-engine ASM revision: $MASTER_ASM_REV"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Atualiza os manifestos com os valores corretos
echo "📝 Preparando manifestos..."

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copia e atualiza manifestos do app-engine
mkdir -p "$TEMP_DIR/app-engine"
cp "$SCRIPT_DIR/app-engine/gateway.yaml" "$TEMP_DIR/app-engine/gateway.yaml"
sed -i.bak "s/MESH_ID/$MESH_ID/g" "$TEMP_DIR/app-engine/gateway.yaml"
sed -i.bak "s/asm-managed/$APP_ASM_REV/g" "$TEMP_DIR/app-engine/gateway.yaml"
rm "$TEMP_DIR/app-engine/gateway.yaml.bak" 2>/dev/null || true

# Copia e atualiza manifestos do master-engine
mkdir -p "$TEMP_DIR/master-engine"
cp "$SCRIPT_DIR/master-engine/gateway.yaml" "$TEMP_DIR/master-engine/gateway.yaml"
sed -i.bak "s/MESH_ID/$MESH_ID/g" "$TEMP_DIR/master-engine/gateway.yaml"
sed -i.bak "s/asm-managed/$MASTER_ASM_REV/g" "$TEMP_DIR/master-engine/gateway.yaml"
rm "$TEMP_DIR/master-engine/gateway.yaml.bak" 2>/dev/null || true

echo "📦 Instalando gateway no cluster app-engine..."
kubectl apply -f "$TEMP_DIR/app-engine/gateway.yaml" --context=$APP_ENGINE_CTX

echo ""
echo "📦 Instalando gateway no cluster master-engine..."
kubectl apply -f "$TEMP_DIR/master-engine/gateway.yaml" --context=$MASTER_ENGINE_CTX

echo ""
echo "⏳ Aguardando gateways ficarem prontos (pode levar 2-5 minutos)..."
echo ""

# Aguarda deployments
for i in {1..30}; do
    APP_READY=$(kubectl get deployment -n istio-system istio-eastwestgateway --context=$APP_ENGINE_CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    MASTER_READY=$(kubectl get deployment -n istio-system istio-eastwestgateway --context=$MASTER_ENGINE_CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    
    if [ "$APP_READY" = "1" ] && [ "$MASTER_READY" = "1" ]; then
        echo "✅ Gateways prontos!"
        break
    fi
    sleep 10
    if [ $((i % 3)) -eq 0 ]; then
        echo "   ⏳ Aguardando... ($i/30)"
    fi
done

echo ""
echo "📊 Status dos gateways:"
echo ""
echo "Cluster app-engine:"
kubectl get svc,deployment -n istio-system --context=$APP_ENGINE_CTX -l istio=eastwestgateway

echo ""
echo "Cluster master-engine:"
kubectl get svc,deployment -n istio-system --context=$MASTER_ENGINE_CTX -l istio=eastwestgateway

echo ""
echo "💡 Aguarde alguns minutos para os IPs do LoadBalancer ficarem disponíveis."
echo "   Execute: kubectl get svc -n istio-system istio-eastwestgateway --context=<contexto>"
echo ""

