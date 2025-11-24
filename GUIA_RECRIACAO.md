# Guia de Recriação Completa da Infraestrutura

Este guia ajuda você a remover os recursos existentes pelo console do GCP e recriar tudo via Terraform com as configurações corretas.

## ⚠️ Importante

- **Backup**: Certifique-se de ter backups de qualquer dado importante
- **Downtime**: Haverá downtime durante a recriação
- **Ordem**: Siga a ordem correta para evitar dependências quebradas

## 📋 Ordem de Remoção (do mais dependente para o menos dependente)

### 1. Remover Node Pools

1. Acesse: **GKE → Clusters → [cluster-name] → Node Pools**
2. Para cada cluster (`master-engine` e `app-engine`):
   - Clique no node pool
   - Clique em **DELETE**
   - Confirme a exclusão
   - Aguarde a remoção completa (pode levar alguns minutos)

### 2. Remover Clusters GKE

1. Acesse: **GKE → Clusters**
2. Para cada cluster:
   - Clique em **DELETE** no cluster `master-engine`
   - Clique em **DELETE** no cluster `app-engine`
   - Aguarde a remoção completa (pode levar 10-15 minutos)

**Verificar remoção:**
```bash
gcloud container clusters list --project=infra-474223
# Deve retornar vazio
```

### 3. Remover Service Mesh Feature (Opcional - será recriado)

1. Acesse: **Anthos → Service Mesh → Features**
2. Se houver feature `servicemesh`:
   - Clique em **DELETE**
   - Ou via CLI:
   ```bash
   gcloud container hub features delete servicemesh \
     --project=infra-474223 \
     --location=global \
     --force
   ```

### 4. Remover Fleet Memberships (Opcional - será recriado)

1. Acesse: **Anthos → Fleet → Memberships**
2. Remover memberships:
   ```bash
   gcloud container fleet memberships delete master-engine-membership \
     --project=infra-474223 \
     --location=global
   
   gcloud container fleet memberships delete app-engine-membership \
     --project=infra-474223 \
     --location=global
   ```

### 5. Limpar Estado do Terraform (IMPORTANTE)

Após remover os recursos pelo console, limpe o estado do Terraform:

```bash
cd /home/user/infra

# Verificar recursos no estado
terraform state list

# Remover recursos do estado (se ainda estiverem lá)
terraform state rm 'module.gke_clusters[0].google_container_cluster.clusters["master-engine"]' || true
terraform state rm 'module.gke_clusters[0].google_container_cluster.clusters["app-engine"]' || true
terraform state rm 'module.gke_clusters[0].google_container_node_pool.node_pools["master-engine"]' || true
terraform state rm 'module.gke_clusters[0].google_container_node_pool.node_pools["app-engine"]' || true
terraform state rm 'module.anthos_service_mesh[0].google_gke_hub_membership.memberships["master-engine"]' || true
terraform state rm 'module.anthos_service_mesh[0].google_gke_hub_membership.memberships["app-engine"]' || true
terraform state rm 'module.anthos_service_mesh[0].google_gke_hub_feature.mesh' || true
terraform state rm 'module.anthos_service_mesh[0].google_gke_hub_feature_membership.mesh_feature_membership["master-engine"]' || true
terraform state rm 'module.anthos_service_mesh[0].google_gke_hub_feature_membership.mesh_feature_membership["app-engine"]' || true
```

## 🚀 Recriação via Terraform

### 1. Verificar Configuração

Certifique-se de que `terraform.tfvars` está correto:

```hcl
gke_clusters = {
  master-engine = {
    machine_type = "e2-standard-4"  # ✅ 4 vCPU
    max_node_count = 4
    # ... outras configurações
  }
  app-engine = {
    machine_type = "e2-standard-4"  # ✅ 4 vCPU
    max_node_count = 4
    # ... outras configurações
  }
}
```

### 2. Inicializar Terraform (se necessário)

```bash
terraform init
```

### 3. Verificar Plano

```bash
terraform plan
```

**O que deve aparecer:**
- ✅ Criação dos clusters GKE
- ✅ Criação dos node pools com `e2-standard-4`
- ✅ Registro no Fleet
- ✅ Configuração do Service Mesh

### 4. Aplicar Infraestrutura

```bash
terraform apply
```

**Tempo estimado:** 15-20 minutos

### 5. Verificar Criação

```bash
# Verificar clusters
gcloud container clusters list --project=infra-474223

# Verificar machine type dos nodes
gcloud container clusters describe master-engine \
  --zone=us-central1-a \
  --project=infra-474223 \
  --format="value(nodePools[0].config.machineType)"
# Deve mostrar: e2-standard-4

gcloud container clusters describe app-engine \
  --zone=us-east1-b \
  --project=infra-474223 \
  --format="value(nodePools[0].config.machineType)"
# Deve mostrar: e2-standard-4

# Verificar Fleet
gcloud container fleet memberships list --project=infra-474223

# Verificar Service Mesh
gcloud container hub features describe servicemesh \
  --project=infra-474223 \
  --location=global
```

## ✅ Checklist Final

- [ ] Node pools removidos
- [ ] Clusters GKE removidos
- [ ] Estado do Terraform limpo
- [ ] `terraform.tfvars` configurado com `e2-standard-4`
- [ ] `terraform plan` mostra criação de recursos
- [ ] `terraform apply` executado com sucesso
- [ ] Clusters criados com `e2-standard-4`
- [ ] Clusters sincronizados no Fleet
- [ ] Service Mesh habilitado e funcionando

## 🔍 Troubleshooting

### Erro: "Already exists" ao recriar

**Causa:** GCP ainda está limpando recursos deletados

**Solução:**
```bash
# Aguardar 10-15 minutos após deletar
# Verificar se recursos foram completamente removidos
gcloud container clusters list --project=infra-474223
# Deve estar vazio

# Se ainda aparecer, forçar remoção:
gcloud container clusters delete master-engine \
  --zone=us-central1-a \
  --project=infra-474223 \
  --quiet || true

gcloud container clusters delete app-engine \
  --zone=us-east1-b \
  --project=infra-474223 \
  --quiet || true
```

### Erro: "Resource not found" no estado

**Causa:** Recurso foi removido mas ainda está no estado do Terraform

**Solução:**
```bash
# Remover do estado (já feito no passo 5 acima)
terraform state rm 'module.gke_clusters[0].google_container_cluster.clusters["master-engine"]'
```

### Service Mesh não sincroniza

**Solução:**
```bash
# Aguardar 5-10 minutos após criar
# Reaplicar módulo do Service Mesh
terraform apply -target=module.anthos_service_mesh
```

## 📝 Notas

- A VPC e subnets **NÃO** precisam ser removidas (podem ser reutilizadas)
- O DNS e Certificate Manager **NÃO** precisam ser removidos
- Apenas os recursos GKE e Service Mesh precisam ser recriados
