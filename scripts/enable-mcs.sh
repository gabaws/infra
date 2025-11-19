#!/bin/bash
# Script para habilitar e configurar Multi-cluster Services (MCS) após o Terraform

set -e

PROJECT_ID="${PROJECT_ID:-infra-474223}"

echo "🔧 Habilitando Multi-cluster Services (MCS)..."
echo ""

# Verificar se o Terraform foi executado
if ! terraform output anthos_service_mesh_status > /dev/null 2>&1; then
  echo "❌ Erro: Execute 'terraform apply' primeiro para criar os clusters e memberships"
  exit 1
fi

# Obter o membership ID do primeiro cluster (config cluster)
echo "📋 Obtendo membership IDs..."
CONFIG_MEMBERSHIP=$(terraform output -json | jq -r '.anthos_service_mesh_status.value.membership_ids | to_entries[0].value')
if [ -z "$CONFIG_MEMBERSHIP" ] || [ "$CONFIG_MEMBERSHIP" = "null" ]; then
  echo "❌ Erro: Não foi possível obter o membership ID do cluster de configuração"
  exit 1
fi

echo "✅ Config cluster membership: $CONFIG_MEMBERSHIP"
echo ""

# Obter todos os membership IDs
MEMBERSHIPS=$(terraform output -json | jq -r '.anthos_service_mesh_status.value.membership_ids | to_entries | map(.value) | join(",")')
echo "✅ Todos os memberships: $MEMBERSHIPS"
echo ""

# 1. Habilitar MCS
echo "1️⃣ Habilitando Multi-cluster Services feature..."
gcloud container fleet multi-cluster-services enable \
  --project="$PROJECT_ID" \
  --quiet

echo "✅ MCS feature habilitada"
echo ""

# Aguardar alguns segundos para a feature ser propagada
echo "⏳ Aguardando propagação da feature..."
sleep 10

# 2. Configurar config_membership
echo "2️⃣ Configurando config_membership..."
gcloud container fleet multi-cluster-services update \
  --config-membership="projects/$PROJECT_ID/locations/global/memberships/$CONFIG_MEMBERSHIP" \
  --project="$PROJECT_ID" \
  --quiet

echo "✅ config_membership configurado"
echo ""

# 3. Registrar todos os clusters
echo "3️⃣ Registrando todos os clusters no MCS..."
gcloud container fleet multi-cluster-services update \
  --config-membership="projects/$PROJECT_ID/locations/global/memberships/$CONFIG_MEMBERSHIP" \
  --memberships="$MEMBERSHIPS" \
  --project="$PROJECT_ID" \
  --quiet

echo "✅ Clusters registrados no MCS"
echo ""

echo "🎉 MCS configurado com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "   1. Aguarde alguns minutos para o MCS propagar a configuração"
echo "   2. Verifique os ServiceExports nos clusters:"
echo "      kubectl get serviceexport -A --context=<contexto>"
echo "   3. Verifique os ServiceImports (criados automaticamente):"
echo "      kubectl get serviceimport -A --context=<contexto>"
echo ""
