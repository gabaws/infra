#!/bin/bash

# Script para limpar o estado do Terraform após remover recursos pelo console do GCP

set -e

echo "🧹 Limpando estado do Terraform..."
echo ""

# Lista de recursos para remover do estado
RESOURCES=(
  'module.gke_clusters[0].google_container_cluster.clusters["master-engine"]'
  'module.gke_clusters[0].google_container_cluster.clusters["app-engine"]'
  'module.gke_clusters[0].google_container_node_pool.node_pools["master-engine"]'
  'module.gke_clusters[0].google_container_node_pool.node_pools["app-engine"]'
  'module.anthos_service_mesh[0].google_gke_hub_membership.memberships["master-engine"]'
  'module.anthos_service_mesh[0].google_gke_hub_membership.memberships["app-engine"]'
  'module.anthos_service_mesh[0].google_gke_hub_feature.mesh'
  'module.anthos_service_mesh[0].google_gke_hub_feature_membership.mesh_feature_membership["master-engine"]'
  'module.anthos_service_mesh[0].google_gke_hub_feature_membership.mesh_feature_membership["app-engine"]'
)

echo "📋 Recursos que serão removidos do estado:"
for resource in "${RESOURCES[@]}"; do
  echo "  - $resource"
done

echo ""
read -p "⚠️  Continuar? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  echo "❌ Operação cancelada"
  exit 1
fi

echo ""
echo "🗑️  Removendo recursos do estado..."

REMOVED=0
NOT_FOUND=0

for resource in "${RESOURCES[@]}"; do
  if terraform state show "$resource" &>/dev/null; then
    echo "  Removendo: $resource"
    terraform state rm "$resource" || true
    REMOVED=$((REMOVED + 1))
  else
    echo "  ⚠️  Não encontrado no estado: $resource"
    NOT_FOUND=$((NOT_FOUND + 1))
  fi
done

echo ""
echo "✅ Limpeza concluída!"
echo "   - Removidos: $REMOVED"
echo "   - Não encontrados: $NOT_FOUND"
echo ""
echo "💡 Próximos passos:"
echo "   1. Verificar que os recursos foram removidos do GCP"
echo "   2. Executar: terraform plan"
echo "   3. Executar: terraform apply"
