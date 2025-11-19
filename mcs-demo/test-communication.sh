#!/bin/bash

# Script para testar comunicação entre clusters usando Multi-cluster Services

# Não usar set -e para permitir tratamento de erros
set +e

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
kubectl get serviceimport -n mcs-demo --context=$APP_ENGINE_CTX 2>/dev/null || echo "  (Nenhum ServiceImport encontrado - isso pode ser normal se ainda não foram criados)"

echo ""
echo "Cluster $MASTER_ENGINE_CLUSTER:"
kubectl get serviceimport -n mcs-demo --context=$MASTER_ENGINE_CTX 2>/dev/null || echo "  (Nenhum ServiceImport encontrado - isso pode ser normal se ainda não foram criados)"

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

# Criar pod de teste com anotação para injeção do sidecar Istio
kubectl run test-pod-app-engine \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n mcs-demo \
  --context=$APP_ENGINE_CTX \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}},"spec":{"containers":[{"name":"test-pod-app-engine","command":["sleep","300"]}]}}}' \
  -- sleep 300

# Aguardar pod ficar pronto
echo "⏳ Aguardando pod ficar pronto..."
kubectl wait --for=condition=Ready pod/test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX --timeout=60s || {
  echo "⚠️  Pod não ficou pronto a tempo. Verificando status..."
  kubectl get pod test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX
  kubectl describe pod test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX | tail -20
  kubectl delete pod test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX --ignore-not-found=true
  echo "❌ Falha na comunicação"
  exit 1
}

# Verificar se o sidecar foi injetado
CONTAINERS=$(kubectl get pod test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}')
echo "📦 Containers no pod: $CONTAINERS"

# Testar comunicação
echo "🌐 Testando comunicação..."
RESULT=$(kubectl exec test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-master-engine.mcs-demo.svc.clusterset.local 2>&1 || echo "ERROR")

if echo "$RESULT" | grep -q "HTTP_CODE:200\|Hello"; then
  echo "✅ Comunicação bem-sucedida!"
  echo "$RESULT" | head -5
else
  echo "❌ Falha na comunicação"
  echo "Resposta: $RESULT"
  echo ""
  echo "🔍 Diagnóstico adicional:"
  kubectl exec test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX -- \
    nslookup hello-master-engine.mcs-demo.svc.clusterset.local 2>&1 || true
fi

# Limpar pod de teste
kubectl delete pod test-pod-app-engine -n mcs-demo --context=$APP_ENGINE_CTX --ignore-not-found=true

echo ""
echo ""
echo "🧪 Teste 2: De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER"
echo ""

# Criar pod de teste com anotação para injeção do sidecar Istio
kubectl run test-pod-master-engine \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n mcs-demo \
  --context=$MASTER_ENGINE_CTX \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}},"spec":{"containers":[{"name":"test-pod-master-engine","command":["sleep","300"]}]}}}' \
  -- sleep 300

# Aguardar pod ficar pronto
echo "⏳ Aguardando pod ficar pronto..."
kubectl wait --for=condition=Ready pod/test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX --timeout=60s || {
  echo "⚠️  Pod não ficou pronto a tempo. Verificando status..."
  kubectl get pod test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX
  kubectl describe pod test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX | tail -20
  kubectl delete pod test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX --ignore-not-found=true
  echo "❌ Falha na comunicação"
  exit 1
}

# Verificar se o sidecar foi injetado
CONTAINERS=$(kubectl get pod test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.spec.containers[*].name}')
echo "📦 Containers no pod: $CONTAINERS"

# Testar comunicação
echo "🌐 Testando comunicação..."
RESULT=$(kubectl exec test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-app-engine.mcs-demo.svc.clusterset.local 2>&1 || echo "ERROR")

if echo "$RESULT" | grep -q "HTTP_CODE:200\|Hello"; then
  echo "✅ Comunicação bem-sucedida!"
  echo "$RESULT" | head -5
else
  echo "❌ Falha na comunicação"
  echo "Resposta: $RESULT"
  echo ""
  echo "🔍 Diagnóstico adicional:"
  kubectl exec test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX -- \
    nslookup hello-app-engine.mcs-demo.svc.clusterset.local 2>&1 || true
fi

# Limpar pod de teste
kubectl delete pod test-pod-master-engine -n mcs-demo --context=$MASTER_ENGINE_CTX --ignore-not-found=true

echo ""
echo "✅ Testes concluídos!"
echo ""
echo "💡 Para mais detalhes, verifique:"
echo "   - kubectl describe serviceexport <nome> -n mcs-demo --context=<contexto>"
echo "   - kubectl get serviceimport -n mcs-demo --context=<contexto>"
echo "   - kubectl logs -n istio-system -l app=istiod --context=<contexto>"
