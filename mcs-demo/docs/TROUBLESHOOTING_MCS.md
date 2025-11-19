# Troubleshooting Multi-cluster Services (MCS)

## 🔍 Problemas Comuns e Soluções

### 1. ❌ Falha na Comunicação entre Clusters

#### Sintomas
- Pods de teste não conseguem se comunicar
- Timeout ao tentar acessar serviços cross-cluster
- DNS não resolve `*.svc.clusterset.local`

#### Verificações

##### 1.1 Verificar ServiceExports
```bash
# Em ambos os clusters
kubectl get serviceexport -n mcs-demo --context=<contexto>
kubectl describe serviceexport <nome> -n mcs-demo --context=<contexto>
```

**Status esperado:**
- `Initialized: True`
- `Exported: True`

**Se não estiver Exported:**
- Verificar se o serviço correspondente existe
- Verificar se o namespace está correto
- Verificar logs do controlador MCS

##### 1.2 Verificar ServiceImports
```bash
# ServiceImports são criados automaticamente pelo MCS
kubectl get serviceimport -n mcs-demo --context=<contexto>
```

**Se não houver ServiceImports:**
- Verificar se os clusters estão no mesmo Fleet
- Verificar se o MCS está habilitado em ambos os clusters
- Aguardar alguns minutos (pode levar tempo para propagar)

##### 1.3 Verificar Serviços MCS
```bash
# Serviços criados automaticamente pelo MCS (gke-mcs-*)
kubectl get svc -n mcs-demo --context=<contexto | grep gke-mcs
```

**Se não houver serviços gke-mcs:**
- O MCS pode não estar funcionando corretamente
- Verificar configuração do Fleet

##### 1.4 Verificar Sidecar do Istio
```bash
# Verificar se os pods têm o sidecar injetado
kubectl get pod <pod-name> -n mcs-demo --context=<contexto> -o jsonpath='{.spec.containers[*].name}'
```

**Resultado esperado:** `hello-server istio-proxy`

**Se não houver istio-proxy:**
- Verificar labels do namespace: `istio-injection: enabled` e `istio.io/rev: asm-managed`
- Verificar anotações do pod: `sidecar.istio.io/inject: "true"`
- Verificar se o ASM está ativo no cluster

##### 1.5 Verificar DNS
```bash
# Dentro de um pod com sidecar
kubectl exec <pod-name> -n mcs-demo --context=<contexto> -- \
  nslookup hello-<service-name>.mcs-demo.svc.clusterset.local
```

**Se DNS não resolver:**
- Verificar se o pod tem o sidecar do Istio
- Verificar configuração do Istio DNS
- Verificar se o ServiceImport existe

##### 1.6 Verificar Conectividade de Rede
```bash
# Verificar se os clusters podem se comunicar
# Testar conectividade direta (se necessário)
kubectl exec <pod-name> -n mcs-demo --context=<contexto> -- \
  curl -v http://hello-<service-name>.mcs-demo.svc.clusterset.local
```

### 2. ⚠️ Pods de Teste Sem Sidecar

#### Problema
Pods criados com `kubectl run` não têm o sidecar do Istio injetado automaticamente.

#### Solução
Usar anotação explícita:
```bash
kubectl run test-pod \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n mcs-demo \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}' \
  -- sleep 300
```

O script `test-communication.sh` já cria pods com sidecar automaticamente.

### 3. 🔄 ServiceExports Não Estão Sendo Exportados

#### Verificações
```bash
# Verificar status do ServiceExport
kubectl describe serviceexport <nome> -n mcs-demo --context=<contexto>

# Verificar eventos
kubectl get events -n mcs-demo --context=<contexto> --sort-by='.lastTimestamp' | grep serviceexport
```

#### Possíveis Causas
1. **Serviço não existe:** O ServiceExport referencia um serviço que não existe
2. **Namespace incorreto:** ServiceExport e Service em namespaces diferentes
3. **MCS não habilitado:** Multi-cluster Services não está habilitado no cluster
4. **Fleet não configurado:** Clusters não estão no mesmo Fleet

### 4. 🌐 DNS Não Resolve *.svc.clusterset.local

#### Verificações
```bash
# Verificar configuração do Istio DNS
kubectl get configmap -n istio-system --context=<contexto> | grep dns

# Verificar se o CoreDNS está configurado corretamente
kubectl get configmap coredns -n kube-system --context=<contexto> -o yaml
```

#### Solução
- Garantir que o ASM está configurado corretamente
- Verificar se o namespace tem os labels corretos
- Reiniciar pods do Istio se necessário

### 5. 🔐 Problemas de Autorização/Segurança

#### Verificações
```bash
# Verificar políticas de autorização do Istio
kubectl get authorizationpolicy -n mcs-demo --context=<contexto>

# Verificar se há políticas bloqueando comunicação
kubectl describe authorizationpolicy <nome> -n mcs-demo --context=<contexto>
```

### 6. 📊 Verificar Logs do Istio

```bash
# Logs do Istiod (control plane)
kubectl logs -n istio-system -l app=istiod --context=<contexto> --tail=100

# Logs do sidecar (istio-proxy)
kubectl logs <pod-name> -n mcs-demo -c istio-proxy --context=<contexto> --tail=100

# Verificar erros específicos
kubectl logs -n istio-system -l app=istiod --context=<contexto> | grep -i error
```

### 7. 🔧 Comandos de Diagnóstico Completo

```bash
# Script de diagnóstico completo
./test-communication.sh

# Verificar configuração do Fleet
gcloud container fleet memberships list --project=<project-id>

# Verificar configuração do ASM
gcloud container fleet mesh describe --project=<project-id>

# Verificar status do MCS
gcloud container fleet multi-cluster-services describe --project=<project-id>
```

## 📋 Checklist de Verificação

Antes de reportar problemas, verifique:

- [ ] Clusters estão no mesmo Fleet do GCP
- [ ] ASM está habilitado em ambos os clusters
- [ ] MCS está habilitado em ambos os clusters
- [ ] Clusters estão na mesma VPC ou VPCs conectadas
- [ ] Namespaces têm labels corretos (`istio-injection: enabled`, `istio.io/rev: asm-managed`)
- [ ] Pods têm anotações corretas (`sidecar.istio.io/inject: "true"`)
- [ ] ServiceExports existem e estão com status `Exported: True`
- [ ] ServiceImports foram criados automaticamente
- [ ] Serviços MCS (gke-mcs-*) existem
- [ ] Pods têm o sidecar do Istio injetado (2/2 containers)
- [ ] DNS resolve `*.svc.clusterset.local`
- [ ] Não há políticas de autorização bloqueando comunicação

## 🔗 Referências

- [Multi-cluster Services Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services)
- [Anthos Service Mesh Multi-cluster](https://cloud.google.com/service-mesh/docs/multicluster-setup)
- [Troubleshooting ASM](https://cloud.google.com/service-mesh/docs/troubleshooting)
