#!/bin/bash

set +e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🔍 Diagnóstico do East-West Gateway"
echo "===================================="
echo ""

# Função para diagnosticar um cluster
diagnosticar_cluster() {
    local context=$1
    local cluster_name=$2
    
    echo "📊 Cluster: $cluster_name"
    echo "────────────────────────────────────────────"
    echo ""
    
    # Verifica se o pod existe
    POD_NAME=$(kubectl get pods -n istio-system --context=$context -l istio=eastwestgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        echo "❌ Nenhum pod do gateway encontrado no namespace istio-system"
        echo ""
        return
    fi
    
    echo "📦 Pod: $POD_NAME"
    echo ""
    
    # Status do pod
    echo "📋 Status do Pod:"
    kubectl get pod $POD_NAME -n istio-system --context=$context
    echo ""
    
    # Descrição detalhada do pod (últimas 30 linhas)
    echo "📋 Descrição Detalhada do Pod (últimos eventos):"
    kubectl describe pod $POD_NAME -n istio-system --context=$context 2>/dev/null | tail -30
    echo ""
    
    # Eventos do pod
    echo "📋 Eventos do Pod:"
    kubectl get events -n istio-system --context=$context --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' 2>/dev/null | tail -10
    echo ""
    
    # Verifica ConfigMaps necessários
    echo "📋 Verificando ConfigMaps necessários:"
    echo ""
    
    REQUIRED_CMPS=("istio-ca-root-cert")
    for cmp in "${REQUIRED_CMPS[@]}"; do
        if kubectl get configmap -n istio-system --context=$context $cmp > /dev/null 2>&1; then
            echo "   ✅ $cmp: existe"
        else
            echo "   ❌ $cmp: NÃO encontrado (CRÍTICO)"
        fi
    done
    
    # Lista todos os ConfigMaps em istio-system para referência
    echo ""
    echo "   📋 Todos os ConfigMaps em istio-system:"
    kubectl get configmap -n istio-system --context=$context 2>/dev/null | head -10 || echo "   ⚠️  Não foi possível listar ConfigMaps"
    echo ""
    
    # Verifica ServiceAccount
    echo "📋 Verificando ServiceAccount:"
    if kubectl get serviceaccount -n istio-system --context=$context istio-eastwestgateway-service-account > /dev/null 2>&1; then
        echo "   ✅ istio-eastwestgateway-service-account: existe"
        echo ""
        echo "   Detalhes:"
        kubectl get serviceaccount -n istio-system --context=$context istio-eastwestgateway-service-account -o yaml | grep -A 5 "name:"
    else
        echo "   ❌ istio-eastwestgateway-service-account: NÃO encontrado"
    fi
    echo ""
    
    # Verifica se o node tem recursos
    echo "📋 Verificando Node onde o pod está agendado:"
    NODE_NAME=$(kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "")
    if [ -n "$NODE_NAME" ]; then
        echo "   Node: $NODE_NAME"
        echo ""
        echo "   Recursos disponíveis:"
        kubectl describe node $NODE_NAME --context=$context 2>/dev/null | grep -A 5 "Allocated resources" || echo "   ⚠️  Não foi possível obter informações do node"
    else
        echo "   ⚠️  Pod ainda não foi agendado em um node"
    fi
    echo ""
    
    # Verifica se há problemas com a imagem
    echo "📋 Verificando configuração do container:"
    IMAGE=$(kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || echo "")
    echo "   Imagem configurada: $IMAGE"
    echo ""
    
    # Verifica volumes
    echo "📋 Verificando volumes:"
    kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.spec.volumes[*].name}' 2>/dev/null | tr ' ' '\n' | while read vol; do
        if [ -n "$vol" ]; then
            echo "   - $vol"
        fi
    done
    echo ""
    
    # Verifica se há condições de erro
    echo "📋 Condições do Pod:"
    kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.status.conditions[*]}' 2>/dev/null | jq -r '.[] | "   \(.type): \(.status) - \(.message)"' 2>/dev/null || \
    kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.status.conditions}' 2>/dev/null | grep -o '"type":"[^"]*","status":"[^"]*"' || echo "   ⚠️  Não foi possível obter condições"
    echo ""
    
    # Verifica se há problemas de pull de imagem
    echo "📋 Verificando eventos de imagem:"
    kubectl get events -n istio-system --context=$context --field-selector involvedObject.name=$POD_NAME 2>/dev/null | grep -i "image\|pull\|error" | tail -5 || echo "   Nenhum evento relacionado a imagem"
    echo ""
    
    # Verifica container status
    echo "📋 Status dos Containers:"
    CONTAINER_STATUS=$(kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.status.containerStatuses[*]}' 2>/dev/null || echo "")
    if [ -n "$CONTAINER_STATUS" ]; then
        echo "$CONTAINER_STATUS" | jq -r '.' 2>/dev/null || echo "   $CONTAINER_STATUS"
    else
        echo "   ⚠️  Sem informações de status dos containers"
    fi
    echo ""
    
    # Verifica se há problemas com Init Containers
    echo "📋 Init Containers:"
    INIT_STATUS=$(kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.status.initContainerStatuses[*].state}' 2>/dev/null || echo "")
    if [ -n "$INIT_STATUS" ] && [ "$INIT_STATUS" != "null" ]; then
        echo "$INIT_STATUS" | jq -r '.' 2>/dev/null || echo "   $INIT_STATUS"
    else
        echo "   ℹ️  Sem Init Containers ou não iniciados ainda"
    fi
    echo ""
    
    # Verifica deployment
    echo "📋 Verificando Deployment:"
    DEPLOYMENT_NAME=$(kubectl get pod $POD_NAME -n istio-system --context=$context -o jsonpath='{.metadata.ownerReferences[?(@.kind=="ReplicaSet")].name}' 2>/dev/null | sed 's/-[a-z0-9]*$//' || echo "")
    if [ -n "$DEPLOYMENT_NAME" ]; then
        echo "   Deployment: $DEPLOYMENT_NAME"
        kubectl get deployment $DEPLOYMENT_NAME -n istio-system --context=$context 2>/dev/null || echo "   ⚠️  Deployment não encontrado"
    else
        echo "   ⚠️  Não foi possível identificar o Deployment"
    fi
    echo ""
    
    echo "────────────────────────────────────────────"
    echo ""
}

# Conecta aos clusters
echo "🔗 Conectando aos clusters..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

gcloud container clusters get-credentials $APP_ENGINE_CLUSTER \
  --location=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

gcloud container clusters get-credentials $MASTER_ENGINE_CLUSTER \
  --location=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo "✅ Clusters conectados!"
echo ""

# Diagnostica ambos os clusters
diagnosticar_cluster $APP_ENGINE_CTX "app-engine"
diagnosticar_cluster $MASTER_ENGINE_CTX "master-engine"

# Resumo
echo "📊 RESUMO DO DIAGNÓSTICO"
echo "===================================="
echo ""

echo "💡 Principais itens a verificar:"
echo ""
echo "1. ConfigMaps necessários:"
echo "   - istio-ca-root-cert (DEVE existir)"
echo ""
echo "2. ServiceAccount:"
echo "   - istio-eastwestgateway-service-account (DEVE existir)"
echo ""
echo "3. Imagem do container:"
echo "   - Verifique se a imagem está correta e acessível"
echo "   - No ASM gerenciado, a imagem deve ser do GCR/GKE"
echo ""
echo "4. Recursos do cluster:"
echo "   - Verifique se há nós disponíveis com recursos suficientes"
echo "   - CPU e memória suficientes para o gateway"
echo ""
echo "5. Problemas comuns:"
echo "   - Falha ao fazer pull da imagem (verificar permissões)"
echo "   - ConfigMap 'istio-ca-root-cert' não encontrado"
echo "   - ServiceAccount sem permissões adequadas"
echo "   - Nós sem recursos suficientes"
echo "   - Problemas de rede (firewall, VPC, etc.)"
echo ""
echo "📋 Comandos úteis para diagnóstico adicional:"
echo ""
echo "   # Ver eventos recentes do namespace:"
echo "   kubectl get events -n istio-system --context=<contexto> --sort-by='.lastTimestamp'"
echo ""
echo "   # Ver logs detalhados do pod (se houver init containers):"
echo "   kubectl logs <nome-do-pod> -n istio-system --context=<contexto>"
echo ""
echo "   # Descrever pod completo:"
echo "   kubectl describe pod <nome-do-pod> -n istio-system --context=<contexto>"
echo ""
echo "   # Ver configuração do deployment:"
echo "   kubectl get deployment istio-eastwestgateway -n istio-system --context=<contexto> -o yaml"
echo ""

