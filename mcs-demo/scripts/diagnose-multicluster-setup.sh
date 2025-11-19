#!/bin/bash

# Script para diagnosticar configuração multi-cluster (ASM vs MCS)

set +e

PROJECT_ID="${PROJECT_ID:-infra-474223}"

echo "🔍 Diagnóstico de Configuração Multi-cluster"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Verificar ASM Multi-cluster
echo "1️⃣ Verificando ASM Multi-cluster (connected mode)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Tentar pegar o contexto atual ou usar o primeiro disponível
CURRENT_CTX=$(kubectl config current-context 2>/dev/null)
if [ -z "$CURRENT_CTX" ]; then
  echo "⚠️  Nenhum contexto kubectl configurado"
  echo "   Configure um contexto primeiro:"
  echo "   kubectl config use-context <contexto>"
else
  echo "📋 Usando contexto: $CURRENT_CTX"
  echo ""
  
  ASM_CONFIG=$(kubectl get configmap asm-options -n istio-system -o yaml 2>/dev/null)
  if [ -n "$ASM_CONFIG" ]; then
    echo "✅ ConfigMap asm-options encontrado:"
    echo "$ASM_CONFIG" | grep -A 2 "multicluster_mode" || echo "   multicluster_mode não encontrado"
    
    MULTICLUSTER_MODE=$(echo "$ASM_CONFIG" | grep "multicluster_mode:" | awk '{print $2}')
    if [ "$MULTICLUSTER_MODE" = "connected" ]; then
      echo ""
      echo "✅ ASM Multi-cluster está em modo 'connected'"
      echo "   Os clusters estão conectados no service mesh"
    else
      echo ""
      echo "⚠️  ASM Multi-cluster não está em modo 'connected'"
      echo "   Modo atual: $MULTICLUSTER_MODE"
    fi
  else
    echo "❌ ConfigMap asm-options não encontrado"
    echo "   ASM pode não estar instalado ou configurado"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣ Verificando MCS (Multi-cluster Services)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MCS_STATUS=$(gcloud container fleet multi-cluster-services describe --project=$PROJECT_ID 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$MCS_STATUS" ]; then
  echo "✅ MCS está habilitado no Fleet:"
  echo "$MCS_STATUS" | head -10
else
  echo "❌ MCS NÃO está habilitado no Fleet"
  echo ""
  echo "💡 Para habilitar MCS, execute:"
  echo "   gcloud container fleet multi-cluster-services enable --project=$PROJECT_ID"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣ Verificando ServiceExports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVICE_EXPORTS=$(kubectl get serviceexport -A 2>/dev/null)
if [ -n "$SERVICE_EXPORTS" ]; then
  echo "✅ ServiceExports encontrados:"
  echo "$SERVICE_EXPORTS"
else
  echo "⚠️  Nenhum ServiceExport encontrado"
  echo "   ServiceExports são necessários para expor serviços via MCS"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣ Verificando ServiceImports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVICE_IMPORTS=$(kubectl get serviceimport -A 2>/dev/null)
if [ -n "$SERVICE_IMPORTS" ]; then
  echo "✅ ServiceImports encontrados (criados automaticamente pelo MCS):"
  echo "$SERVICE_IMPORTS"
else
  echo "⚠️  Nenhum ServiceImport encontrado"
  echo "   ServiceImports são criados automaticamente pelo MCS quando há ServiceExports"
  echo "   Se não há ServiceImports, o MCS pode não estar funcionando corretamente"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣ Verificando Serviços MCS (gke-mcs-*)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MCS_SERVICES=$(kubectl get svc -A 2>/dev/null | grep gke-mcs)
if [ -n "$MCS_SERVICES" ]; then
  echo "✅ Serviços MCS encontrados (criados automaticamente):"
  echo "$MCS_SERVICES"
else
  echo "⚠️  Nenhum serviço MCS (gke-mcs-*) encontrado"
  echo "   Estes serviços são criados automaticamente pelo MCS"
  echo "   Se não existem, o MCS não está funcionando"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣ Resumo e Diagnóstico"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ASM_CONNECTED=false
MCS_ENABLED=false

if [ "$MULTICLUSTER_MODE" = "connected" ]; then
  ASM_CONNECTED=true
fi

if [ -n "$MCS_STATUS" ] && [ -n "$SERVICE_IMPORTS" ]; then
  MCS_ENABLED=true
fi

echo "📊 Estado Atual:"
echo ""
echo "   ASM Multi-cluster (connected): $([ "$ASM_CONNECTED" = true ] && echo "✅ Habilitado" || echo "❌ Não habilitado")"
echo "   MCS (Multi-cluster Services):   $([ "$MCS_ENABLED" = true ] && echo "✅ Habilitado" || echo "❌ Não habilitado")"
echo ""

if [ "$ASM_CONNECTED" = true ] && [ "$MCS_ENABLED" = false ]; then
  echo "🔴 PROBLEMA IDENTIFICADO:"
  echo ""
  echo "   ✅ ASM Multi-cluster está conectado"
  echo "   ❌ MCS NÃO está habilitado"
  echo ""
  echo "   📋 Situação:"
  echo "      Os clusters estão conectados no service mesh (ASM),"
  echo "      mas os serviços NÃO são expostos automaticamente entre clusters."
  echo ""
  echo "   💡 Soluções:"
  echo ""
  echo "      Opção 1: Habilitar MCS (Recomendado)"
  echo "      ─────────────────────────────────────"
  echo "      gcloud container fleet multi-cluster-services enable --project=$PROJECT_ID"
  echo ""
  echo "      Opção 2: Configurar manualmente no ASM"
  echo "      ─────────────────────────────────────"
  echo "      Criar ServiceEntry e VirtualService manualmente"
  echo "      (Veja documentação em docs/ASM_MULTICLUSTER_VS_MCS.md)"
  echo ""
elif [ "$ASM_CONNECTED" = false ]; then
  echo "⚠️  ASM Multi-cluster não está conectado"
  echo "   Configure o ASM multi-cluster primeiro"
elif [ "$MCS_ENABLED" = true ]; then
  echo "✅ Tudo configurado corretamente!"
  echo "   ASM e MCS estão funcionando"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Diagnóstico concluído!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Para mais informações, consulte:"
echo "   docs/ASM_MULTICLUSTER_VS_MCS.md"
