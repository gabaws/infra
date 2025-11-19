#!/bin/bash

# Script para diagnosticar pods pendentes

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔍 Diagnóstico de Pods Pendentes"
echo ""

diagnose_cluster() {
  local CLUSTER_NAME=$1
  local CONTEXT=$2
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 Cluster: $CLUSTER_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
 
  echo "1️⃣ Verificando nós disponíveis..."
  NODES=$(kubectl get nodes --context=$CONTEXT --no-headers 2>/dev/null | wc -l)
  if [ "$NODES" -eq 0 ]; then
    echo "  ❌ Nenhum nó encontrado no cluster!"
  else
    echo "  ✅ Encontrados $NODES nó(s)"
    echo ""
    echo "  Detalhes dos nós:"
    kubectl get nodes --context=$CONTEXT -o wide
  fi
  echo ""
  
 
  echo "2️⃣ Verificando pods pendentes..."
  PENDING_PODS=$(kubectl get pods -n mcs-demo --context=$CONTEXT --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
  if [ "$PENDING_PODS" -gt 0 ]; then
    echo "  ⚠️  Encontrados $PENDING_PODS pod(s) pendente(s)"
    echo ""
    
    
    kubectl get pods -n mcs-demo --context=$CONTEXT --field-selector=status.phase=Pending -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | while read POD; do
      if [ -n "$POD" ]; then
        echo "  ──────────────────────────────────────────────"
        echo "  📦 Pod: $POD"
        echo "  ──────────────────────────────────────────────"
        echo ""
        
        echo "  📋 Status detalhado:"
        kubectl get pod $POD -n mcs-demo --context=$CONTEXT -o jsonpath='{.status}' 2>/dev/null | jq '.' 2>/dev/null || kubectl get pod $POD -n mcs-demo --context=$CONTEXT -o yaml 2>/dev/null | grep -A 20 "status:" || echo "    Não foi possível obter status"
        echo ""
        
        echo "  📋 Condições do pod:"
        kubectl get pod $POD -n mcs-demo --context=$CONTEXT -o jsonpath='{.status.conditions[*]}' 2>/dev/null | jq -r '.[] | "    \(.type): \(.status) - \(.message // "sem mensagem")"' 2>/dev/null || kubectl describe pod $POD -n mcs-demo --context=$CONTEXT 2>/dev/null | grep -A 10 "Conditions:" || echo "    Não foi possível obter condições"
        echo ""
        
        echo "  📋 Eventos recentes:"
        kubectl get events -n mcs-demo --context=$CONTEXT --field-selector involvedObject.name=$POD --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "    Nenhum evento encontrado"
        echo ""
        
        echo "  📋 Describe completo (últimas linhas):"
        kubectl describe pod $POD -n mcs-demo --context=$CONTEXT 2>/dev/null | tail -30 || echo "    Não foi possível obter describe"
        echo ""
      fi
    done
  else
    echo "  ✅ Nenhum pod pendente encontrado"
  fi
  echo ""
  
  
  echo "3️⃣ Verificando recursos disponíveis nos nós..."
  echo ""
  kubectl top nodes --context=$CONTEXT 2>/dev/null || echo "  ⚠️  Métricas não disponíveis (pode ser necessário habilitar metrics-server)"
  echo ""
  
 
  echo "4️⃣ Verificando requests/limits dos pods..."
  echo ""
  kubectl get pods -n mcs-demo --context=$CONTEXT -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}' 2>/dev/null | while read LINE; do
    if [ -n "$LINE" ]; then
      POD_NAME=$(echo "$LINE" | cut -f1)
      RESOURCES=$(echo "$LINE" | cut -f2-)
      echo "  Pod: $POD_NAME"
      echo "$RESOURCES" | jq '.' 2>/dev/null || echo "    $RESOURCES"
      echo ""
    fi
  done
  
  echo "5️⃣ Verificando taints nos nós..."
  echo ""
  kubectl get nodes --context=$CONTEXT -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints}{"\n"}{end}' 2>/dev/null | while read LINE; do
    if [ -n "$LINE" ]; then
      NODE_NAME=$(echo "$LINE" | cut -f1)
      TAINTS=$(echo "$LINE" | cut -f2-)
      if [ "$TAINTS" != "null" ] && [ -n "$TAINTS" ]; then
        echo "  Nó: $NODE_NAME"
        echo "$TAINTS" | jq '.' 2>/dev/null || echo "    $TAINTS"
        echo ""
      fi
    fi
  done
  
 
  echo "6️⃣ Verificando node selectors nos deployments..."
  echo ""
  kubectl get deployments -n mcs-demo --context=$CONTEXT -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.nodeSelector}{"\n"}{end}' 2>/dev/null | while read LINE; do
    if [ -n "$LINE" ]; then
      DEPLOY_NAME=$(echo "$LINE" | cut -f1)
      NODE_SELECTOR=$(echo "$LINE" | cut -f2-)
      if [ "$NODE_SELECTOR" != "null" ] && [ -n "$NODE_SELECTOR" ]; then
        echo "  Deployment: $DEPLOY_NAME"
        echo "$NODE_SELECTOR" | jq '.' 2>/dev/null || echo "    $NODE_SELECTOR"
        echo ""
      fi
    fi
  done
  
  
  echo "7️⃣ Verificando tolerations nos deployments..."
  echo ""
  kubectl get deployments -n mcs-demo --context=$CONTEXT -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.tolerations}{"\n"}{end}' 2>/dev/null | while read LINE; do
    if [ -n "$LINE" ]; then
      DEPLOY_NAME=$(echo "$LINE" | cut -f1)
      TOLERATIONS=$(echo "$LINE" | cut -f2-)
      if [ "$TOLERATIONS" != "null" ] && [ -n "$TOLERATIONS" ]; then
        echo "  Deployment: $DEPLOY_NAME"
        echo "$TOLERATIONS" | jq '.' 2>/dev/null || echo "    $TOLERATIONS"
        echo ""
      fi
    fi
  done
  
  echo ""
}


diagnose_cluster "$APP_ENGINE_CLUSTER" "$APP_ENGINE_CTX"
diagnose_cluster "$MASTER_ENGINE_CLUSTER" "$MASTER_ENGINE_CTX"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Diagnóstico concluído!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Comandos úteis para investigação adicional:"
echo "   - kubectl describe pod <pod-name> -n mcs-demo --context=<contexto>"
echo "   - kubectl get events -n mcs-demo --context=<contexto> --sort-by='.lastTimestamp'"
echo "   - kubectl get nodes --context=<contexto> -o yaml"
echo "   - kubectl top nodes --context=<contexto>"
echo ""
