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

# Função para instalar gateway em um cluster
install_gateway() {
    local context=$1
    local cluster_name=$2
    
    echo "📦 Instalando East-West Gateway no cluster $cluster_name..."
    
    # Verifica se já existe
    if kubectl get svc -n istio-system --context=$context istio-eastwestgateway > /dev/null 2>&1; then
        echo "   ✅ Gateway já existe no cluster $cluster_name"
        return 0
    fi
    
    # Cria o IstioOperator para o gateway
    kubectl apply --context=$context -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwestgateway
  namespace: istio-system
spec:
  profile: empty
  components:
    ingressGateways:
    - name: istio-eastwestgateway
      label:
        istio: eastwestgateway
        app: istio-eastwestgateway
      enabled: true
      k8s:
        env:
        - name: ISTIO_META_ROUTER_MODE
          value: "sni-dnat"
        service:
          type: LoadBalancer
          ports:
          - name: tls
            port: 15443
            targetPort: 15443
            protocol: TCP
          annotations:
            cloud.google.com/load-balancer-type: "External"
EOF

    echo "   ⏳ Aguardando gateway ficar pronto (pode levar 2-3 minutos)..."
    
    # Aguarda o serviço ser criado
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get svc -n istio-system --context=$context istio-eastwestgateway > /dev/null 2>&1; then
            echo "   ✅ Gateway criado!"
            break
        fi
        sleep 10
        attempt=$((attempt + 1))
        echo "   ⏳ Aguardando... ($attempt/$max_attempts)"
    done
    
    # Aguarda o IP do LoadBalancer
    echo "   ⏳ Aguardando IP do LoadBalancer..."
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        local ip=$(kubectl get svc -n istio-system --context=$context istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$ip" ]; then
            echo "   ✅ IP do gateway: $ip"
            return 0
        fi
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "   ⚠️  Gateway criado, mas IP ainda não disponível. Aguarde alguns minutos."
}

install_gateway $APP_ENGINE_CTX "app-engine"
echo ""
install_gateway $MASTER_ENGINE_CTX "master-engine"

echo ""
echo "✅ Instalação concluída!"
echo ""
echo "📊 Status dos gateways:"
echo ""
echo "Cluster app-engine:"
kubectl get svc -n istio-system --context=$APP_ENGINE_CTX istio-eastwestgateway 2>/dev/null || echo "   ⚠️  Gateway não encontrado"

echo ""
echo "Cluster master-engine:"
kubectl get svc -n istio-system --context=$MASTER_ENGINE_CTX istio-eastwestgateway 2>/dev/null || echo "   ⚠️  Gateway não encontrado"

echo ""
echo "💡 Se os IPs ainda não aparecerem, aguarde alguns minutos e execute novamente:"
echo "   kubectl get svc -n istio-system --context=<contexto> istio-eastwestgateway"
echo ""

