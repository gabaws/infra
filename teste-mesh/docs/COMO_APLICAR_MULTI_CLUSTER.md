# Como Aplicar MultiClusterService

## 📋 Cenário

Você tem dois cenários de teste:
1. **Sem multi-cluster** - Usa ServiceEntry (já configurado)
2. **Com multi-cluster** - Usa MultiClusterService (novo)

Os arquivos `multicluster-service.yaml` foram criados mas **não estão no kustomization padrão** para não interferir nos testes sem multi-cluster.

---

## 🚀 Opção 1: Aplicar MultiClusterService Manualmente

### Cluster A (dev-dis-app-engine)

```bash
cd gke-dev-dis-app-engine

# Aplicar tudo EXCETO o MultiClusterService
kubectl apply -k .

# Aplicar MultiClusterService separadamente
kubectl apply -f multicluster-service.yaml \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine
```

### Cluster B (dev-get-app-engine)

```bash
cd gke-dev-get-app-engine

# Aplicar tudo EXCETO o MultiClusterService
kubectl apply -k .

# Aplicar MultiClusterService separadamente
kubectl apply -f multicluster-service.yaml \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

---

## 🚀 Opção 2: Criar kustomization separado

Você pode criar um `kustomization-multicluster.yaml` em cada diretório:

### gke-dev-dis-app-engine/kustomization-multicluster.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - virtual-service.yaml
  - gateway.yaml
  - namespace.yaml
  - multicluster-service.yaml
```

### Aplicar

```bash
# Cluster A
cd gke-dev-dis-app-engine
kubectl apply -k . --kustomize-file=kustomization-multicluster.yaml \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Cluster B
cd ../gke-dev-get-app-engine
kubectl apply -k . --kustomize-file=kustomization-multicluster.yaml \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

---

## 🚀 Opção 3: Aplicar diretamente o arquivo

```bash
# Cluster A
kubectl apply -f gke-dev-dis-app-engine/multicluster-service.yaml \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Cluster B
kubectl apply -f gke-dev-get-app-engine/multicluster-service.yaml \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

---

## ✅ Verificar

```bash
# Verificar MultiClusterService no Cluster A
kubectl get multiclusterservice -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine

# Verificar MultiClusterService no Cluster B
kubectl get multiclusterservice -n dev-get-test \
  --context=gke_prj-dev-get-app-gke-cple_southamerica-east1_gke-dev-get-app-engine
```

---

## 🧪 Testar DNS

```bash
# No Cluster A, testar DNS do serviço do Cluster B
POD_NAME=$(kubectl get pod -l app=dev-dis-test -n dev-dis-test \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -o jsonpath='{.items[0].metadata.name}')

# Testar DNS do MultiClusterService (clusterset.local)
kubectl exec -n dev-dis-test $POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- nslookup dev-get-test.dev-get-test.svc.clusterset.local

# Testar comunicação HTTP
kubectl exec -n dev-dis-test $POD_NAME \
  --context=gke_prj-dev-dis-app-gke-cple_southamerica-east1_gke-dev-dis-app-engine \
  -- curl http://dev-get-test.dev-get-test.svc.clusterset.local:80/
```

---

## 📝 Notas Importantes

1. **ServiceEntry vs MultiClusterService**: Ambos podem coexistir
   - ServiceEntry: `servicename.namespace.svc.cluster.local` (sem multi-cluster)
   - MultiClusterService: `servicename.namespace.svc.clusterset.local` (com multi-cluster)

2. **DNS diferente**: O MultiClusterService usa `.svc.clusterset.local` em vez de `.svc.cluster.local`

3. **Aplicar em ambos os clusters**: O MultiClusterService precisa ser aplicado em ambos os clusters para funcionar

4. **Clusters no spec**: Certifique-se de que os nomes dos clusters no `multicluster-service.yaml` correspondem aos nomes reais dos seus clusters

---

## 🔍 Verificar Nomes dos Clusters

Se os nomes dos clusters estiverem diferentes, você pode verificar:

```bash
# Listar clusters no fleet
gcloud container fleet memberships list

# Ver detalhes de um membership
gcloud container fleet memberships describe MEMBERSHIP_NAME --location=global
```

Os nomes no `multicluster-service.yaml` devem corresponder aos nomes dos clusters no GKE Hub.
