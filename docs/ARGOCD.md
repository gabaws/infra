# Instalação Manual do ArgoCD

Este guia descreve como instalar e configurar o ArgoCD manualmente no cluster `master-engine` após a infraestrutura base estar provisionada.

## 📋 Pré-requisitos

1. Infraestrutura base provisionada via Terraform
2. Acesso ao cluster GKE `master-engine`
3. `kubectl` e `helm` instalados localmente
4. Certificado wildcard já emitido no Certificate Manager

## 🔧 Passo 1: Conectar ao Cluster

```bash
# Obter credenciais do cluster
gcloud container clusters get-credentials master-engine \
  --zone us-central1-a \
  --project infra-474223
```

## 🔧 Passo 2: Instalar Istio Ingress Gateway

O ASM gerenciado não instala automaticamente o Ingress Gateway. Você precisa instalá-lo:

```bash
# Adicionar repositório do Istio
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Instalar Istio Ingress Gateway
helm install istio-ingressgateway istio/gateway \
  --namespace istio-system \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set service.annotations."cloud\.google\.com/load-balancer-type"=External \
  --set labels.istio=ingressgateway \
  --version 1.20.0
```

Aguarde alguns minutos para o LoadBalancer ser provisionado:

```bash
# Verificar o IP externo
kubectl get svc istio-ingressgateway -n istio-system -w
```

## 🔧 Passo 3: Instalar ArgoCD

```bash
# Adicionar repositório do ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Instalar ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.3.6 \
  --set server.service.type=ClusterIP \
  --set server.insecure=true \
  --set configs.params."server\.insecure"=true \
  --set configs.cm.url="https://argocd.cloudab.online"
```

## 🔧 Passo 4: Criar Istio Gateway e VirtualService

Crie o arquivo `argocd-gateway.yaml`:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: argocd
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - argocd.cloudab.online
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - argocd.cloudab.online
    tls:
      mode: SIMPLE
      credentialName: argocd-tls-cert
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - argocd.cloudab.online
  gateways:
  - argocd/argocd-gateway
  http:
  - match:
    - port: 80
    redirect:
      uri: ""
      authority: https://argocd.cloudab.online
      redirectCode: 301
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        # IMPORTANTE: O nome do serviço depende do nome do Helm release
        # Se você instalou com: helm install argocd ... então o serviço será: argocd-server
        # Se você instalou com: helm install master-engine-argocd ... então o serviço será: master-engine-argocd-server
        host: argocd-server.argocd.svc.cluster.local
        port:
          number: 80
```

Aplique o Gateway e VirtualService:

```bash
kubectl apply -f argocd-gateway.yaml
```

## 🔧 Passo 5: Criar Secret TLS

O Certificate Manager do GCP não cria automaticamente Secrets para Istio. Você precisa criar o Secret TLS manualmente.

### Opção 1: Usar cert-manager (Recomendado)

```bash
# Instalar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Aguardar cert-manager estar pronto
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Criar ClusterIssuer para Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: seu-email@exemplo.com  # Altere para seu email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudDNS:
          project: infra-474223
          serviceAccountSecretRef:
            name: clouddns-dns01-solver-svc-acct
            key: key.json
EOF

# Criar Certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls-cert
  namespace: istio-system
spec:
  secretName: argocd-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - argocd.cloudab.online
  - '*.cloudab.online'
EOF
```

### Opção 2: Criar Secret Manualmente

Se você já tem o certificado e a chave privada:

```bash
kubectl create secret tls argocd-tls-cert \
  --cert=cert.pem \
  --key=key.pem \
  -n istio-system
```

## 🔧 Passo 6: Criar Registro DNS

Após obter o IP externo do Istio Ingress Gateway:

```bash
# Obter o IP
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Criar registro DNS via gcloud
gcloud dns record-sets create argocd.cloudab.online. \
  --zone=public-zone-cloudab-online \
  --type=A \
  --rrdatas=$INGRESS_IP \
  --ttl=300 \
  --project=infra-474223
```

Ou via Terraform (se preferir):

```bash
# Obter o IP
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Atualizar o Terraform state ou criar manualmente
```

## 🔧 Passo 7: Obter Senha Inicial do ArgoCD

```bash
# Obter a senha do admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## ✅ Verificação

1. **Verificar pods do ArgoCD:**
   ```bash
   kubectl get pods -n argocd
   ```

2. **Verificar Gateway e VirtualService:**
   ```bash
   kubectl get gateway,virtualservice -n argocd
   ```

3. **Verificar IP do LoadBalancer:**
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system
   ```

4. **Acessar ArgoCD:**
   - URL: `https://argocd.cloudab.online`
   - Usuário: `admin`
   - Senha: (obtida no Passo 7)

## 🔍 Troubleshooting

### ArgoCD não está acessível

1. **Verificar se o DNS está resolvendo:**
   ```bash
   nslookup argocd.cloudab.online
   ```

2. **Verificar logs do Istio Ingress Gateway:**
   ```bash
   kubectl logs -n istio-system -l istio=ingressgateway --tail=50
   ```

3. **Verificar se o VirtualService está correto:**
   ```bash
   kubectl get virtualservice argocd-vs -n argocd -o yaml
   ```

4. **Verificar se o serviço do ArgoCD está correto:**
   ```bash
   kubectl get svc -n argocd
   # O nome do serviço deve ser: argocd-server
   ```

### Certificado TLS não funciona

1. **Verificar se o Secret existe:**
   ```bash
   kubectl get secret argocd-tls-cert -n istio-system
   ```

2. **Verificar se o certificado está válido:**
   ```bash
   kubectl get certificate -n istio-system
   ```

3. **Verificar logs do cert-manager (se usando):**
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager
   ```

## 📚 Referências

- [Documentação do ArgoCD](https://argo-cd.readthedocs.io/)
- [Istio Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [cert-manager](https://cert-manager.io/docs/)

