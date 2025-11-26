# Módulo Karpenter para GKE

Este módulo instala e configura o Karpenter nos clusters GKE usando arquivos YAML separados para melhor organização e manutenção.

## 📁 Estrutura do Módulo

```
modules/karpenter/
├── main.tf                    # Recursos Terraform principais
├── variables.tf               # Variáveis de entrada
├── outputs.tf                 # Outputs do módulo
├── README.md                  # Esta documentação
└── manifests/                 # Arquivos YAML separados
    ├── namespace.yaml          # Template do Namespace
    └── serviceaccount.yaml    # Template do Service Account
```

## 🎯 Por que Arquivos YAML Separados?

### ✅ Vantagens:

1. **Organização**: Manifests Kubernetes separados do código Terraform
2. **Manutenibilidade**: Mais fácil de editar e revisar os YAMLs
3. **Reutilização**: Os YAMLs podem ser usados diretamente com kubectl se necessário
4. **Versionamento**: Mudanças nos YAMLs são mais claras no Git
5. **Validação**: Pode validar os YAMLs independentemente

### 📝 Como Funciona:

O Terraform usa a função `templatefile()` para:
1. Ler o arquivo YAML do diretório `manifests/`
2. Substituir as variáveis `${variavel}` pelos valores reais
3. Aplicar o YAML renderizado no cluster via `kubectl`

## 🔧 Arquivos YAML

### `manifests/namespace.yaml`

Define o namespace onde o Karpenter será instalado:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
  labels:
    app.kubernetes.io/name: karpenter
    app.kubernetes.io/instance: karpenter
```

**Variáveis:**
- `${namespace}`: Nome do namespace (padrão: `karpenter`)

### `manifests/serviceaccount.yaml`

Define o Service Account Kubernetes com Workload Identity:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: ${namespace}
  annotations:
    iam.gke.io/gcp-service-account: ${gcp_service_account_email}
```

**Variáveis:**
- `${namespace}`: Nome do namespace
- `${gcp_service_account_email}`: Email do Service Account do GCP

## 📋 Uso

```hcl
module "karpenter" {
  source = "./modules/karpenter"

  project_id = "meu-projeto"
  
  clusters = {
    cluster1 = {
      cluster_name     = "cluster1"
      cluster_location = "us-central1-a"
    }
  }
  
  karpenter_version      = "v0.37.0"
  default_instance_types = ["e2-standard-2", "e2-standard-4"]
}
```

## 🔄 Fluxo de Execução

1. **Service Accounts do GCP**: Cria os service accounts com permissões necessárias
2. **Workload Identity**: Configura o binding entre GCP e Kubernetes
3. **Namespace**: Aplica `manifests/namespace.yaml` via kubectl
4. **Service Account Kubernetes**: Aplica `manifests/serviceaccount.yaml` via kubectl
5. **Helm Install**: Instala o Karpenter via Helm chart

## 🛠️ Personalização

Para modificar os manifests:

1. Edite os arquivos em `manifests/`
2. Adicione novas variáveis se necessário
3. Atualize o `templatefile()` no `main.tf` para passar as novas variáveis

**Exemplo**: Adicionar labels customizados ao namespace:

```yaml
# manifests/namespace.yaml
metadata:
  name: ${namespace}
  labels:
    app.kubernetes.io/name: karpenter
    environment: ${environment}  # Nova variável
```

```hcl
# main.tf
templatefile("${path.module}/manifests/namespace.yaml", {
  namespace  = var.karpenter_namespace
  environment = "production"  # Nova variável
})
```

## 📚 Referências

- [Karpenter GCP Provider](https://github.com/cloudpilot-ai/karpenter-provider-gcp)
- [Terraform templatefile()](https://www.terraform.io/docs/language/functions/templatefile.html)

