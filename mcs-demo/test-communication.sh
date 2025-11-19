#!/bin/bash

# Script para testar comunicação entre clusters usando Multi-cluster Services
# Usa os pods existentes (hello-app-engine e hello-master-engine) para testar

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🧪 Teste de Comunicação Multi-cluster Services"
echo ""

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
echo "📋 Verificando ServiceExports..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get serviceexport -n mcs-demo --context=$APP_ENGINE_CTX

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceexport -n mcs-demo --context=$MASTER_ENGINE_CTX

echo ""
echo "📋 Verificando ServiceImports (criados automaticamente pelo MCS)..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get serviceimport -n mcs-demo --context=$APP_ENGINE_CTX 2>/dev/null || echo "  (Nenhum ServiceImport encontrado)"

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceimport -n mcs-demo --context=$MASTER_ENGINE_CTX 2>/dev/null || echo "  (Nenhum ServiceImport encontrado)"

echo ""
echo "📋 Verificando serviços MCS (gke-mcs-*)..."
echo ""
echo "Cluster $APP_ENGINE_CLUSTER:"
kubectl get svc -n mcs-demo --context=$APP_ENGINE_CTX | grep gke-mcs || echo "  (Nenhum serviço MCS encontrado)"

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get svc -n mcs-demo --context=$MASTER_ENGINE_CTX | grep gke-mcs || echo "  (Nenhum serviço MCS encontrado)"

echo ""
echo "🧪 Teste 1: De $APP_ENGINE_CLUSTER para $MASTER_ENGINE_CLUSTER"
echo ""

# Pegar o primeiro pod do cluster app-engine
APP_POD=$(kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$APP_POD" ]; then
  echo "❌ Nenhum pod hello-app-engine encontrado no cluster $APP_ENGINE_CLUSTER"
  exit 1
fi

echo "📦 Usando pod: $APP_POD"
echo "📦 Verificando containers no pod..."
CONTAINERS=$(kubectl get pod $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
echo "Containers: $CONTAINERS"

# Verificar se tem sidecar istio-proxy
if echo "$CONTAINERS" | grep -q "istio-proxy"; then
  echo "✅ Sidecar istio-proxy encontrado"
  echo ""
  echo "🌐 Testando comunicação usando sidecar istio-proxy..."
  
  # Usar curl do sidecar istio-proxy
  RESULT=$(kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c istio-proxy -- \
    curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-master-engine.mcs-demo.svc.clusterset.local:80 2>&1 || echo "ERROR")
  
  if echo "$RESULT" | grep -q "HTTP_CODE:200\|Hello"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "$RESULT" | head -5
  else
    echo "❌ Falha na comunicação"
    echo "Resposta: $RESULT"
    echo ""
    echo "🔍 Diagnóstico adicional:"
    echo "Testando DNS..."
    kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c istio-proxy -- \
      nslookup hello-master-engine.mcs-demo.svc.clusterset.local 2>&1 || true
  fi
else
  echo "⚠️  Sidecar istio-proxy não encontrado. Tentando usar container principal..."
  # Tentar usar o container principal (pode não ter curl)
  RESULT=$(kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c hello-server -- \
    wget -qO- --timeout=10 http://hello-master-engine.mcs-demo.svc.clusterset.local:80 2>&1 || echo "ERROR")
  
  if echo "$RESULT" | grep -q "Hello"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "$RESULT" | head -5
  else
    echo "❌ Falha na comunicação ou ferramenta não disponível no container"
    echo "Resposta: $RESULT"
  fi
fi

echo ""
echo ""
echo "🧪 Teste 2: De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER"
echo ""

# Pegar o primeiro pod do cluster master-engine
MASTER_POD=$(kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MASTER_POD" ]; then
  echo "❌ Nenhum pod hello-master-engine encontrado no cluster $MASTER_ENGINE_CLUSTER"
  exit 1
fi

echo "📦 Usando pod: $MASTER_POD"
echo "📦 Verificando containers no pod..."
CONTAINERS=$(kubectl get pod $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
echo "Containers: $CONTAINERS"

# Verificar se tem sidecar istio-proxy
if echo "$CONTAINERS" | grep -q "istio-proxy"; then
  echo "✅ Sidecar istio-proxy encontrado"
  echo ""
  echo "🌐 Testando comunicação usando sidecar istio-proxy..."
  
  # Usar curl do sidecar istio-proxy
  RESULT=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c istio-proxy -- \
    curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-app-engine.mcs-demo.svc.clusterset.local:80 2>&1 || echo "ERROR")
  
  if echo "$RESULT" | grep -q "HTTP_CODE:200\|Hello"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "$RESULT" | head -5
  else
    echo "❌ Falha na comunicação"
    echo "Resposta: $RESULT"
    echo ""
    echo "🔍 Diagnóstico adicional:"
    echo "Testando DNS..."
    kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c istio-proxy -- \
      nslookup hello-app-engine.mcs-demo.svc.clusterset.local 2>&1 || true
  fi
else
  echo "⚠️  Sidecar istio-proxy não encontrado. Tentando usar container principal..."
  # Tentar usar o container principal (pode não ter curl)
  RESULT=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
    wget -qO- --timeout=10 http://hello-app-engine.mcs-demo.svc.clusterset.local:80 2>&1 || echo "ERROR")
  
  if echo "$RESULT" | grep -q "Hello"; then
    echo "✅ Comunicação bem-sucedida!"
    echo "$RESULT" | head -5
  else
    echo "❌ Falha na comunicação ou ferramenta não disponível no container"
    echo "Resposta: $RESULT"
  fi
fi

echo ""
echo "✅ Testes concluídos!"
echo ""
echo "💡 Para mais detalhes, verifique:"
echo "   - kubectl describe serviceexport <nome> -n mcs-demo --context=<contexto>"
echo "   - kubectl get serviceimport -n mcs-demo --context=<contexto>"
echo "   - kubectl logs -n istio-system -l app=istiod --context=<contexto>"
