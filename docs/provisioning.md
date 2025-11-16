# Provisionamento & Pipeline

Este documento descreve como a infraestrutura é criada e mantida usando Terraform e GitHub Actions.

---

## 1. Visão Geral

1. **Backend**: estado remoto em bucket GCS (veja [docs/BACKEND_AND_STATE.md](./BACKEND_AND_STATE.md)).
2. **Terraform**: estrutura modular (`main.tf` + módulos em `modules/`).
3. **GitHub Actions**: pipeline `terraform-deploy.yaml` roda automaticamente em duas fases.

---

## 2. Pré-requisitos

- Terraform ≥ 1.3
- gcloud SDK ≥ 269
- jq ≥ 1.6
- Service Account com permissões de criação/gerenciamento no projeto `infra-474223`
- Workload Identity configurada para o GitHub (`terraform-deployer@infra-474223.iam.gserviceaccount.com`)

---

## 3. Fluxo do GitHub Actions

```text
[Push / PR]
   |
   v
[Job: terraform-plan]
   ├─ detecta se clusters já existem
   ├─ exporta TF_VAR_enable_cluster_addons (true/false)
   └─ publica plano
   |
   v
[Job: terraform-apply-bootstrap]
   └─ roda apenas se clusters ainda não existem (enable_cluster_addons=false)
   |
   v
[Job: terraform-apply-addons]
   └─ roda sempre que houver mudanças e executa enable_cluster_addons=true
```

**Fase 1 – Bootstrap (`enable_cluster_addons=false`)**
- Cria VPC, sub-redes, Cloud NAT, clusters GKE e registra no GKE Hub.

**Fase 2 – Add-ons (`enable_cluster_addons=true`)**
- Instala Istio (base + istiod + gateways) e ArgoCD (apenas no cluster master).
- Usa `manage_istio_namespace=false` para evitar recriar o namespace `istio-system` quando o ASM já o provisiona.

---

## 4. Execução Manual

```bash
# 1. (opcional) backend
cd bootstrap && cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 2. autenticar
gcloud auth application-default login

# 3. definir variáveis
cp terraform.tfvars.example terraform.tfvars
# edite os valores necessários

# 4. aplicar duas fases
terraform apply -var enable_cluster_addons=false
terraform apply -var enable_cluster_addons=true
```

> Em execuções futuras, basta rodar `terraform apply` (o estado já indica se os clusters existem).

---

## 5. Estrutura dos jobs

| Job | Objetivo | Observações |
| --- | --- | --- |
| `detect-changes` | Determina se há alterações relevantes | Usa `dorny/paths-filter` |
| `terraform-plan` | `init`, `fmt`, `validate` e `plan` | Ajusta `TF_VAR_enable_cluster_addons` com base no estado |
| `terraform-apply-bootstrap` | Executa fase 1 | Só roda se os clusters não existem |
| `terraform-apply-addons` | Executa fase 2 | Sempre que houver mudanças aprovadas |

---

## 6. Estrutura do repositório

```
.
├── bootstrap/                 # módulo para criar o bucket do estado
├── modules/
│   ├── vpc/                   # rede, subnets e Cloud NAT
│   ├── gke/                   # clusters + node pools
│   ├── cluster-addons/        # Istio + gateways + ArgoCD
│   └── anthos-service-mesh/   # registro no GKE Hub / ASM
├── .github/workflows/terraform-deploy.yaml
├── docs/
└── main.tf / variables.tf / outputs.tf
```

---

## 7. Testes e verificação

- `terraform plan` deve mostrar apenas os recursos que realmente precisam mudar.
- `terraform output gke_clusters` retorna endpoints e certificados (sensíveis).
- Para verificar a malha:
  ```bash
  gcloud container clusters get-credentials master-engine --zone us-central1-a
  kubectl get ns istio-system
  kubectl get servicemesh -A
  ```

---

## 8. Boas práticas adotadas

- Clusters privados com Workload Identity e Network Policy.
- Istio/ASM instalado via Helm com revision `asm-managed`.
- ArgoCD centralizado no cluster master (`argocd_target_cluster`).
- `manage_istio_namespace` configurável para evitar conflitos com namespaces já existentes.
- Bucket de estado com versionamento e lock.

---

## 9. Próximos passos

- Adicionar testes automatizados (ex.: `kubectl` smoke tests) após o job de add-ons.
- Integrar notificações em PR para falhas na fase 2.
- Criar políticas adicionais de segurança (ex.: Pod Security Standards) via ArgoCD.

