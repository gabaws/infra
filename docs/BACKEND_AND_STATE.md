# Backend Remoto e Gerenciamento de Estado

## 📋 Respostas às Suas Perguntas

### 1. O tfstate é armazenado em um bucket?

**Sim!** O estado do Terraform será armazenado em um bucket GCS (Google Cloud Storage) para:
- ✅ Compartilhamento de estado entre equipe
- ✅ Versionamento do estado (com versioning habilitado)
- ✅ Locking de estado (evita conflitos)
- ✅ Backup automático
- ✅ Integração com CI/CD

### 2. O Terraform provisiona o bucket antes de usar?

**Não automaticamente!** O Terraform precisa que o bucket exista ANTES de configurar o backend remoto. Por isso criamos o módulo `bootstrap/` que você deve executar primeiro.

**Processo correto:**

1. **Primeiro**: Criar o bucket (bootstrap)
2. **Depois**: Configurar o backend no Terraform
3. **Por fim**: Migrar o estado local para o bucket

### 3. O workflow roda apenas alterações específicas?

**Parcialmente correto!** O Terraform sempre faz um **plan completo** (analisa toda a infraestrutura), mas:

- ✅ O **workflow detecta mudanças** em diretórios específicos
- ✅ O **workflow só executa** se houver mudanças relevantes
- ⚠️ O **terraform plan** sempre analisa tudo (é assim que o Terraform funciona)
- ✅ Você pode usar `-target` para aplicar apenas recursos específicos (mas não é recomendado em produção)

## 🚀 Como Configurar o Backend

### Passo 1: Criar o Bucket (Bootstrap)

```bash
cd bootstrap/
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas informações

terraform init
terraform apply
```

Isso criará:
- Bucket GCS para o estado
- Versioning habilitado
- IAM configurado

### Passo 2: Configurar o Backend no Terraform

Edite `versions.tf` e descomente o backend:

```hcl
terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket-seu-projeto"  # Nome do bucket criado
    prefix = "terraform/state"
  }
}
```

### Passo 3: Migrar o Estado Local

Se você já tem um estado local:

```bash
terraform init -migrate-state
```

O Terraform perguntará se você quer migrar o estado. Digite `yes`.

### Passo 4: Verificar

```bash
terraform init
terraform plan
```

Se tudo estiver OK, você verá:
```
Initializing the backend...
Successfully configured the backend "gcs"!
```

## 📁 Estrutura do Estado no Bucket

```
gs://terraform-state-bucket/
└── terraform/
    └── state/
        └── default.tfstate
```

## 🔒 Segurança do Backend

### Versioning
O bucket tem versioning habilitado, então você pode:
- Ver histórico de mudanças no estado
- Reverter para versões anteriores se necessário

### IAM
Configure permissões adequadas:
- **Admins**: `roles/storage.objectAdmin` (pode ler/escrever)
- **Readers**: `roles/storage.objectViewer` (apenas leitura, para CI/CD)

### Encryption
O bucket pode usar KMS para criptografia adicional (opcional).

## 🔄 Como o Workflow Funciona

### Detecção de Mudanças

O workflow usa `dorny/paths-filter` para detectar mudanças:

```yaml
filters:
  vpc:
    - 'modules/vpc/**'
    - 'main.tf'
  gke:
    - 'modules/gke/**'
    - 'main.tf'
  mesh:
    - 'modules/anthos-service-mesh/**'
```

### Comportamento

1. **Pull Request**: Apenas `terraform plan` (não aplica)
2. **Push para main**: `terraform plan` + `terraform apply`
3. **Sem mudanças relevantes**: Workflow não executa

### Terraform Plan vs Apply

- **Plan**: Sempre analisa TODA a infraestrutura (é assim que o Terraform funciona)
- **Apply**: Aplica apenas o que mudou (Terraform é inteligente nisso)

### Aplicação Direcionada (Targeted)

Você pode usar `-target` para aplicar apenas recursos específicos:

```bash
terraform apply -target=module.vpc
```

⚠️ **Cuidado**: Usar `-target` pode criar dependências quebradas. Use apenas em emergências ou desenvolvimento.

## 📊 Exemplo de Fluxo

### Cenário 1: Alteração apenas na VPC

1. Você altera `modules/vpc/main.tf`
2. Workflow detecta mudança em `vpc`
3. Workflow executa `terraform plan` (analisa tudo)
4. Plan mostra: "VPC será modificada, outros recursos sem mudanças"
5. Workflow executa `terraform apply` (aplica apenas mudanças na VPC)

### Cenário 2: Alteração em múltiplos módulos

1. Você altera VPC e GKE
2. Workflow detecta mudanças em ambos
3. `terraform plan` mostra todas as mudanças
4. `terraform apply` aplica todas as mudanças necessárias

### Cenário 3: Sem mudanças relevantes

1. Você altera apenas `README.md`
2. Workflow não detecta mudanças em arquivos `.tf`
3. Workflow não executa (economiza recursos)

## 🛠️ Troubleshooting

### Erro: "Backend configuration changed"

Se você mudou o backend, execute:
```bash
terraform init -reconfigure
```

### Erro: "Error loading state: bucket not found"

O bucket não existe. Execute o bootstrap primeiro:
```bash
cd bootstrap/
terraform apply
```

### Erro: "Error acquiring the state lock"

Alguém está executando Terraform no mesmo estado. Aguarde ou force unlock (cuidado!):
```bash
terraform force-unlock <LOCK_ID>
```

### Estado corrompido

Com versioning habilitado, você pode restaurar:
```bash
gsutil cp gs://bucket/terraform/state/default.tfstate#<VERSION> \
  gs://bucket/terraform/state/default.tfstate
```

## 📚 Boas Práticas

1. ✅ **Sempre use backend remoto** em produção
2. ✅ **Nunca commite** arquivos `.tfstate` no Git
3. ✅ **Use versioning** no bucket
4. ✅ **Configure IAM** adequadamente
5. ✅ **Faça backup** regular do estado (com versioning, já está feito)
6. ✅ **Use workspaces** para ambientes diferentes (dev, staging, prod)
7. ⚠️ **Evite `-target`** em produção (pode quebrar dependências)

## 🔗 Referências

- [Terraform Backends](https://www.terraform.io/docs/language/settings/backends/index.html)
- [GCS Backend](https://www.terraform.io/docs/language/settings/backends/gcs.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)

