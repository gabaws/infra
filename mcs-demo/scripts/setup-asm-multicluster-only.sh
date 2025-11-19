#!/bin/bash

# Script para configurar comunicação multi-cluster usando apenas ASM (ServiceEntry + VirtualService)
# SEM usar MCS - simula o cenário onde só tem ASM multi-cluster conectado

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔧 Configurando Comunicação Multi-cluster via ASM (SEM MCS)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Obter ClusterIPs dos serviços
echo "1️⃣ Obtendo ClusterIPs dos serviços..."
echo ""

MASTER_SVC_IP=$(kubectl get svc hello-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
APP_SVC_IP=$(kubectl get svc hello-app-engine -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [ -z "$MASTER_SVC_IP" ] || [ "$MASTER_SVC_IP" = "null" ]; then
  echo "❌ Não foi possível obter ClusterIP do serviço hello-master-engine"
  echo "   Verifique se o serviço existe no cluster $MASTER_ENGINE_CLUSTER"
  exit 1
fi

if [ -z "$APP_SVC_IP" ] || [ "$APP_SVC_IP" = "null" ]; then
  echo "❌ Não foi possível obter ClusterIP do serviço hello-app-engine"
  echo "   Verifique se o serviço existe no cluster $APP_ENGINE_CLUSTER"
  exit 1
fi

echo "✅ ClusterIPs obtidos:"
echo "   hello-master-engine: $MASTER_SVC_IP"
echo "   hello-app-engine: $APP_SVC_IP"
echo ""

# 2. Criar ServiceEntry e VirtualService para app-engine (acessar master-engine)
echo "2️⃣ Configurando cluster $APP_ENGINE_CLUSTER para acessar $MASTER_ENGINE_CLUSTER..."
echo ""

# Criar ServiceEntry temporário
cat > /tmp/serviceentry-master.yaml <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: hello-master-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-master-engine-remote.mcs-demo.svc.cluster.local
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: STATIC
  addresses:
  - $MASTER_SVC_IP
  location: MESH_INTERNAL
  endpoints:
  - address: $MASTER_SVC_IP
    ports:
      http: 80
EOF

# Criar VirtualService temporário
cat > /tmp/virtualservice-master.yaml <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: hello-master-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-master-engine-remote.mcs-demo.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: hello-master-engine-remote.mcs-demo.svc.cluster.local
        port:
          number: 80
      weight: 100
EOF

kubectl apply -f /tmp/serviceentry-master.yaml --context=$APP_ENGINE_CTX
kubectl apply -f /tmp/virtualservice-master.yaml --context=$APP_ENGINE_CTX

echo "✅ ServiceEntry e VirtualService criados no cluster $APP_ENGINE_CLUSTER"
echo ""

# 3. Criar ServiceEntry e VirtualService para master-engine (acessar app-engine)
echo "3️⃣ Configurando cluster $MASTER_ENGINE_CLUSTER para acessar $APP_ENGINE_CLUSTER..."
echo ""

# Criar ServiceEntry temporário
cat > /tmp/serviceentry-app.yaml <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: hello-app-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-app-engine-remote.mcs-demo.svc.cluster.local
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: STATIC
  addresses:
  - $APP_SVC_IP
  location: MESH_INTERNAL
  endpoints:
  - address: $APP_SVC_IP
    ports:
      http: 80
EOF

# Criar VirtualService temporário
cat > /tmp/virtualservice-app.yaml <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: hello-app-engine-remote
  namespace: mcs-demo
spec:
  hosts:
  - hello-app-engine-remote.mcs-demo.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: hello-app-engine-remote.mcs-demo.svc.cluster.local
        port:
          number: 80
      weight: 100
EOF

kubectl apply -f /tmp/serviceentry-app.yaml --context=$MASTER_ENGINE_CTX
kubectl apply -f /tmp/virtualservice-app.yaml --context=$MASTER_ENGINE_CTX

echo "✅ ServiceEntry e VirtualService criados no cluster $MASTER_ENGINE_CLUSTER"
echo ""

# Limpar arquivos temporários
rm -f /tmp/serviceentry-*.yaml /tmp/virtualservice-*.yaml

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Configuração concluída!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Resumo:"
echo ""
echo "   Cluster $APP_ENGINE_CLUSTER pode acessar:"
echo "   → hello-master-engine-remote.mcs-demo.svc.cluster.local"
echo ""
echo "   Cluster $MASTER_ENGINE_CLUSTER pode acessar:"
echo "   → hello-app-engine-remote.mcs-demo.svc.cluster.local"
echo ""
echo "💡 IMPORTANTE:"
echo "   - Usamos .svc.cluster.local (não .svc.clusterset.local)"
echo "   - Isso funciona apenas com ASM multi-cluster conectado"
echo "   - NÃO requer MCS habilitado"
echo ""
echo "🧪 Para testar:"
echo "   ./scripts/test-asm-multicluster-only.sh"
echo ""
