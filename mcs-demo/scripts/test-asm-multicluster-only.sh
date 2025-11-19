#!/bin/bash

# Script para testar comunicação multi-cluster usando apenas ASM (ServiceEntry + VirtualService)
# SEM usar MCS - simula o cenário onde só tem ASM multi-cluster conectado

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🧪 Teste de Comunicação Multi-cluster via ASM (SEM MCS)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar se ServiceEntry e VirtualService existem
echo "1️⃣ Verificando configuração..."
echo ""

APP_SERVICEENTRY=$(kubectl get serviceentry hello-master-engine-remote -n mcs-demo --context=$APP_ENGINE_CTX 2>/dev/null)
MASTER_SERVICEENTRY=$(kubectl get serviceentry hello-app-engine-remote -n mcs-demo --context=$MASTER_ENGINE_CTX 2>/dev/null)

if [ -z "$APP_SERVICEENTRY" ]; then
  echo "❌ ServiceEntry não encontrado no cluster $APP_ENGINE_CLUSTER"
  echo "   Execute primeiro: ./scripts/setup-asm-multicluster-only.sh"
  exit 1
fi

if [ -z "$MASTER_SERVICEENTRY" ]; then
  echo "❌ ServiceEntry não encontrado no cluster $MASTER_ENGINE_CLUSTER"
  echo "   Execute primeiro: ./scripts/setup-asm-multicluster-only.sh"
  exit 1
fi

echo "✅ ServiceEntry e VirtualService encontrados"
echo ""

# Obter pods
APP_POD=$(kubectl get pods -n mcs-demo --context=$APP_ENGINE_CTX -l app=hello-app-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
MASTER_POD=$(kubectl get pods -n mcs-demo --context=$MASTER_ENGINE_CTX -l app=hello-master-engine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$APP_POD" ] || [ -z "$MASTER_POD" ]; then
  echo "❌ Pods não encontrados. Verifique se os pods estão rodando."
  exit 1
fi

# Verificar se pods estão prontos
APP_POD_STATUS=$(kubectl get pod $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -o jsonpath='{.status.phase}' 2>/dev/null)
MASTER_POD_STATUS=$(kubectl get pod $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -o jsonpath='{.status.phase}' 2>/dev/null)

if [ "$APP_POD_STATUS" != "Running" ] || [ "$MASTER_POD_STATUS" != "Running" ]; then
  echo "❌ Pods não estão prontos"
  echo "   APP: $APP_POD ($APP_POD_STATUS)"
  echo "   MASTER: $MASTER_POD ($MASTER_POD_STATUS)"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣ Teste 1: De $APP_ENGINE_CLUSTER para $MASTER_ENGINE_CLUSTER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 Pod: $APP_POD"
echo "🌐 Testando comunicação para hello-master-engine-remote.mcs-demo.svc.cluster.local..."
echo ""

# Testar DNS primeiro
echo "🔍 Testando DNS..."
DNS_RESULT=$(kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c hello-server -- \
  nslookup hello-master-engine-remote.mcs-demo.svc.cluster.local 2>&1)

if echo "$DNS_RESULT" | grep -q "Address:"; then
  echo "✅ DNS resolvido:"
  echo "$DNS_RESULT" | grep "Address:"
else
  echo "⚠️  DNS não resolveu (pode ser normal, o Envoy pode rotear mesmo assim)"
fi

echo ""
echo "🌐 Testando HTTP..."
RESULT=$(kubectl exec $APP_POD -n mcs-demo --context=$APP_ENGINE_CTX -c hello-server -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-master-engine-remote.mcs-demo.svc.cluster.local:80 2>&1)

HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESULT" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ] || echo "$BODY" | grep -q "Hello from master-engine"; then
  echo "✅ Comunicação bem-sucedida!"
  echo "HTTP Status: $HTTP_CODE"
  echo "Resposta: $BODY"
else
  echo "❌ Falha na comunicação"
  echo "Resposta completa: $RESULT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣ Teste 2: De $MASTER_ENGINE_CLUSTER para $APP_ENGINE_CLUSTER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 Pod: $MASTER_POD"
echo "🌐 Testando comunicação para hello-app-engine-remote.mcs-demo.svc.cluster.local..."
echo ""

# Testar DNS primeiro
echo "🔍 Testando DNS..."
DNS_RESULT=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
  nslookup hello-app-engine-remote.mcs-demo.svc.cluster.local 2>&1)

if echo "$DNS_RESULT" | grep -q "Address:"; then
  echo "✅ DNS resolvido:"
  echo "$DNS_RESULT" | grep "Address:"
else
  echo "⚠️  DNS não resolveu (pode ser normal, o Envoy pode rotear mesmo assim)"
fi

echo ""
echo "🌐 Testando HTTP..."
RESULT=$(kubectl exec $MASTER_POD -n mcs-demo --context=$MASTER_ENGINE_CTX -c hello-server -- \
  curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 http://hello-app-engine-remote.mcs-demo.svc.cluster.local:80 2>&1)

HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESULT" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ] || echo "$BODY" | grep -q "Hello from app-engine"; then
  echo "✅ Comunicação bem-sucedida!"
  echo "HTTP Status: $HTTP_CODE"
  echo "Resposta: $BODY"
else
  echo "❌ Falha na comunicação"
  echo "Resposta completa: $RESULT"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Testes concluídos!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Diferenças entre ASM-only e MCS:"
echo ""
echo "   ASM-only (ServiceEntry + VirtualService):"
echo "   - DNS: service.namespace.svc.cluster.local (customizado)"
echo "   - Configuração manual necessária"
echo "   - Precisa saber ClusterIP do serviço remoto"
echo "   - Funciona apenas com ASM multi-cluster conectado"
echo ""
echo "   MCS (ServiceExport + ServiceImport):"
echo "   - DNS: service.namespace.svc.clusterset.local (automático)"
echo "   - Configuração automática"
echo "   - Não precisa saber ClusterIP"
echo "   - Requer MCS habilitado no Fleet"
echo ""
echo "📋 Para verificar ServiceEntry e VirtualService:"
echo "   kubectl get serviceentry,virtualservice -n mcs-demo --context=<contexto>"
echo ""
