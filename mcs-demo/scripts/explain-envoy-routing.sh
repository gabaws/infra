#!/bin/bash

# Script para explicar e demonstrar como o Envoy (ASM) roteia o tráfego

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔍 Explicando Roteamento do Envoy (ASM)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Pegar um pod de cada cluster
MASTER_POD=$(kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
APP_POD=$(kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MASTER_POD" ] || [ -z "$APP_POD" ]; then
  echo "❌ Não foi possível encontrar pods. Verifique se os pods estão rodando."
  exit 1
fi

echo "📋 Pods encontrados:"
echo "   Master: $MASTER_POD"
echo "   App: $APP_POD"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣ Verificando Containers nos Pods"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Cluster $MASTER_ENGINE_CLUSTER - Pod: $MASTER_POD"
CONTAINERS_MASTER=$(kubectl get pod $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
echo "   Containers: $CONTAINERS_MASTER"
echo ""

echo "Cluster $APP_ENGINE_CLUSTER - Pod: $APP_POD"
CONTAINERS_APP=$(kubectl get pod $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
echo "   Containers: $CONTAINERS_APP"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣ Fazendo Requisição e Analisando Headers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📤 De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER:"
echo ""
RESPONSE=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
  curl -s -i http://hello-app-engine.mcs-demo.svc.clusterset.local 2>&1)

echo "$RESPONSE" | head -15
echo ""

# Verificar se tem header "server: envoy"
if echo "$RESPONSE" | grep -qi "server:.*envoy"; then
  echo "✅ Header 'server: envoy' encontrado!"
  echo "   Isso confirma que o tráfego passou pelo sidecar Envoy"
fi

# Verificar header x-envoy-upstream-service-time
if echo "$RESPONSE" | grep -qi "x-envoy-upstream-service-time"; then
  TIME=$(echo "$RESPONSE" | grep -i "x-envoy-upstream-service-time" | cut -d: -f2 | tr -d ' ')
  echo "✅ Header 'x-envoy-upstream-service-time: $TIME' encontrado!"
  echo "   Tempo que o Envoy levou para processar a requisição (em ms)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣ Verificando Configuração do Envoy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 Listando clusters conhecidos pelo Envoy no pod $MASTER_POD:"
echo ""
kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c istio-proxy -- \
  curl -s http://localhost:15000/clusters 2>/dev/null | \
  grep "hello-app-engine" | head -5 || echo "   (Não foi possível acessar as métricas do Envoy)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣ Fluxo do Tráfego"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Quando você faz curl de um pod para outro:"
echo ""
echo "1. 📤 Pod Origem (hello-master-engine):"
echo "   └─ Container: hello-server"
echo "      └─ Faz curl → sai do pod"
echo "         └─ Interceptado pelo istio-proxy (sidecar)"
echo ""
echo "2. 🔄 Sidecar Envoy (istio-proxy) no pod origem:"
echo "   ├─ Resolve DNS: hello-app-engine.mcs-demo.svc.clusterset.local"
echo "   ├─ Aplica políticas (mTLS, rate limiting, etc.)"
echo "   ├─ Adiciona headers de telemetria"
echo "   └─ Roteia para o cluster de destino"
echo ""
echo "3. 🌐 Rede Multi-cluster:"
echo "   └─ Tráfego atravessa a rede entre clusters"
echo ""
echo "4. 🔄 Sidecar Envoy (istio-proxy) no pod destino:"
echo "   ├─ Recebe o tráfego"
echo "   ├─ Valida mTLS"
echo "   ├─ Aplica políticas de entrada"
echo "   └─ Encaminha para o container hello-server"
echo ""
echo "5. 📥 Pod Destino (hello-app-engine):"
echo "   └─ Container: hello-server"
echo "      └─ Processa a requisição"
echo "         └─ Resposta volta pelo mesmo caminho"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣ Headers Importantes do Envoy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Headers que o Envoy adiciona:"
echo ""
echo "   • server: envoy"
echo "      └─ Indica que a resposta passou pelo Envoy"
echo ""
echo "   • x-envoy-upstream-service-time: <ms>"
echo "      └─ Tempo que o serviço upstream levou para responder"
echo ""
echo "   • x-request-id: <uuid>"
echo "      └─ ID único para rastreamento (distributed tracing)"
echo ""
echo "   • x-envoy-attempt-count: <número>"
echo "      └─ Número de tentativas de retry"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Explicação Completa!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 O header 'server: envoy' confirma que:"
echo "   1. O ASM está ativo e roteando o tráfego"
echo "   2. O tráfego está passando pelo sidecar do Istio"
echo "   3. As políticas do service mesh estão sendo aplicadas"
echo "   4. A comunicação multi-cluster está funcionando"
echo ""
