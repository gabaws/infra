# Arquitetura da Solução

Descrição textual da infraestrutura provisionada e guia para reproduzir o diagrama no draw.io.

---

## 1. Componentes principais

| Camada | Elementos |
| --- | --- |
| Projeto GCP | Projeto `infra-474223`, billing conectado e APIs essenciais habilitadas |
| Rede | VPC `main-vpc`, sub-redes privadas (`subnet-us-central1`, `subnet-us-east1`), Cloud NAT + Private Google Access |
| Clusters GKE | `master-engine` (us-central1-a) e `app-engine` (us-east1-b), ambos privados, com Workload Identity e Node Pools gerenciados |
| Service Mesh | Anthos Service Mesh (via GKE Hub), certificação mTLS, políticas multi-cluster |
| Add-ons | Istio base + istiod, ingress gateway e ArgoCD (apenas no cluster master) |
| Observabilidade | Logging, Monitoring e Managed Prometheus habilitados sob demanda |

---

## 2. Fluxo lógico (ASCII)

```text
┌────────────────────────────────────────────────────────────┐
│ Projeto GCP: infra-474223                                  │
│                                                            │
│  ┌─────── VPC main-vpc ───────┐    ┌───── Cloud NAT ─────┐ │
│  │                            │    │  Private Access    │ │
│  │  subnet-us-central1        │    └────────────────────┘ │
│  │    └── cluster master-engine (ArgoCD + Istio)          │
│  │                                                        │
│  │  subnet-us-east1                                       │
│  │    └── cluster app-engine (Istio)                      │
│  └────────────────────────────────────────────────────────┘
│            │                     │
│            └────── Anthos Service Mesh (mTLS, políticas)──┘
│                              │
│                        Observabilidade (Logging / Monitoring)
└────────────────────────────────────────────────────────────┘
```

---

## 3. Responsabilidades por cluster

- **master-engine**
  - Recebe o ArgoCD (`argocd_target_cluster`).
  - Expõe gateways Istio conforme `install_gateway`.
  - Participa da malha via ASM.

- **app-engine**
  - Participa da mesma malha.
  - Recebe workloads sincronizados pelo ArgoCD a partir do cluster master.

Ambos os clusters compartilham as mesmas práticas de segurança (Workload Identity, Network Policy, Binary Authorization).

---

## 4. Como montar o diagrama no draw.io

1. Abra [https://app.diagrams.net](https://app.diagrams.net).
2. Crie um novo diagrama em branco.
3. Adicione as seguintes caixas (na ordem):
   - **Projeto GCP** (retângulo grande envolvendo tudo).
   - **VPC main-vpc** (retângulo interno).
   - Duas caixas menores para as sub-redes (`us-central1`, `us-east1`).
   - Dentro de cada subnet, desenhe um ícone/hexágono para o cluster GKE correspondente.
   - Adicione um balão/shape para "Cloud NAT + Private Access".
   - Desenhe uma elipse conectando os dois clusters com o rótulo "Anthos Service Mesh".
   - Fora da VPC, adicione caixas para "GitHub Actions", "Bucket GCS (tfstate)" e setas indicando o fluxo.
4. Use setas tracejadas para representar tráfego mTLS entre os clusters.
5. Salve o arquivo como `docs/architecture.drawio` e exporte para SVG se desejar.

Sugestão de legenda:

- Azul: camadas de rede/VPC.
- Roxo: clusters GKE.
- Laranja: componentes GitOps (ArgoCD).
- Azul-claro: elementos de mesh/observabilidade.

---

## 5. Regras de segurança principais

- Clusters privados (sem IP público nos nós / endpoint privado opcional).
- Workload Identity habilitada (`project-id.svc.id.goog`).
- Network Policy ativa em ambos os clusters.
- Binary Authorization configurado em modo `PROJECT_SINGLETON_POLICY_ENFORCE`.
- `manage_istio_namespace=false` por padrão para evitar conflitos com namespaces criados automaticamente pelo ASM.

---

## 6. Expansões futuras

- Adicionar mais regiões/sub-redes apenas replicando o bloco correspondente em `var.subnets`.
- Criar novos clusters adicionando entradas em `var.gke_clusters` + providers `kubernetes/helm` extras.
- Incluir serviços de dados (Cloud SQL, Memorystore) na mesma VPC, aproveitando o Service Mesh para roteamento seguro.

