# Como Habilitar Multi-cluster Ingress Manualmente

## ⚠️ Problema

O Terraform não consegue criar a feature `multiclusteringress` porque ela requer um `config_membership` que não pode ser configurado diretamente via Terraform atualmente.

## ✅ Solução

Habilite o Multi-cluster Ingress manualmente via `gcloud` após o Terraform aplicar a infraestrutura.

## 📋 Pré-requisitos

1. ✅ Terraform aplicado com sucesso
2. ✅ Clusters registrados no GKE Hub (Fleet)
3. ✅ `gcloud` CLI instalado e autenticado

## 🚀 Passos

### Passo 1: Obter Membership IDs

Primeiro, obtenha os IDs dos memberships criados pelo Terraform:

```bash
# Via Terraform output
terraform output gke_hub_membership_ids

# Ou via gcloud
gcloud container fleet memberships list --project=infra-474223
```

### Passo 2: Escolher o Config Cluster

Escolha qual cluster será o **config cluster** (geralmente o primeiro cluster ou o cluster principal). O membership ID será algo como:
- `projects/infra-474223/locations/global/memberships/master-engine-membership`
- `projects/infra-474223/locations/global/memberships/app-engine-membership`

### Passo 3: Habilitar Multi-cluster Ingress

```bash
# Substitua PROJECT_ID e MEMBERSHIP_ID pelos valores corretos
PROJECT_ID="infra-474223"
CONFIG_MEMBERSHIP="projects/${PROJECT_ID}/locations/global/memberships/master-engine-membership"

# Habilitar a feature
gcloud container fleet ingress enable \
  --config-membership=${CONFIG_MEMBERSHIP} \
  --project=${PROJECT_ID}
```

### Passo 4: Registrar Clusters na Feature

```bash
# Obter todos os membership IDs
MEMBERSHIP_1="projects/${PROJECT_ID}/locations/global/memberships/master-engine-membership"
MEMBERSHIP_2="projects/${PROJECT_ID}/locations/global/memberships/app-engine-membership"

# Registrar ambos os clusters
gcloud container fleet ingress update \
  --config-membership=${MEMBERSHIP_1} \
  --memberships=${MEMBERSHIP_1},${MEMBERSHIP_2} \
  --project=${PROJECT_ID}
```

### Passo 5: Verificar Status

```bash
# Verificar se a feature está ativa
gcloud container fleet features describe multiclusteringress \
  --location=global \
  --project=${PROJECT_ID}

# Verificar memberships registrados
gcloud container fleet memberships list --project=${PROJECT_ID}
```

## 📝 Script Completo

```bash
#!/bin/bash

PROJECT_ID="infra-474223"
CONFIG_MEMBERSHIP_ID="master-engine-membership"  # Cluster que será o config cluster
CONFIG_MEMBERSHIP="projects/${PROJECT_ID}/locations/global/memberships/${CONFIG_MEMBERSHIP_ID}"

# Obter todos os membership IDs
MEMBERSHIPS=$(gcloud container fleet memberships list \
  --project=${PROJECT_ID} \
  --format="value(name)" \
  --filter="name:*-membership")

# Converter para formato de lista separada por vírgulas
MEMBERSHIP_LIST=$(echo $MEMBERSHIPS | tr ' ' ',')

echo "Habilitando Multi-cluster Ingress..."
gcloud container fleet ingress enable \
  --config-membership=${CONFIG_MEMBERSHIP} \
  --project=${PROJECT_ID}

echo "Registrando clusters na feature..."
gcloud container fleet ingress update \
  --config-membership=${CONFIG_MEMBERSHIP} \
  --memberships=${MEMBERSHIP_LIST} \
  --project=${PROJECT_ID}

echo "Verificando status..."
gcloud container fleet features describe multiclusteringress \
  --location=global \
  --project=${PROJECT_ID}
```

## 🔗 Referências

- [Multi-cluster Ingress Setup](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup)
- [gcloud container fleet ingress](https://cloud.google.com/sdk/gcloud/reference/container/fleet/ingress)

## ⚠️ Nota Importante

Após habilitar manualmente, o Terraform não gerenciará essa feature. Se você precisar recriar a infraestrutura, será necessário habilitar novamente manualmente após o `terraform apply`.
