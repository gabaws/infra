#!/bin/bash

set -e

PROJECT_ID="infra-474223"
APP_ENGINE_CLUSTER="app-engine"
APP_ENGINE_LOCATION="us-east1-b"
MASTER_ENGINE_CLUSTER="master-engine"
MASTER_ENGINE_LOCATION="us-central1-a"

APP_ENGINE_CTX="gke_${PROJECT_ID}_${APP_ENGINE_LOCATION}_${APP_ENGINE_CLUSTER}"
MASTER_ENGINE_CTX="gke_${PROJECT_ID}_${MASTER_ENGINE_LOCATION}_${MASTER_ENGINE_CLUSTER}"

echo "🚀 Instalando East-West Gateway para ASM Multi-cluster"
echo ""

if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud não está instalado."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não está instalado."
    exit 1
fi

echo "📋 Configurando projeto..."
gcloud config set project $PROJECT_ID > /dev/null 2>&1

echo "🔗 Conectando aos clusters..."
gcloud container clusters get-credentials $APP_ENGINE_CLUSTER \
  --location=$APP_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

gcloud container clusters get-credentials $MASTER_ENGINE_CLUSTER \
  --location=$MASTER_ENGINE_LOCATION \
  --project=$PROJECT_ID > /dev/null 2>&1

echo "✅ Clusters conectados!"
echo ""

# Obtém o Mesh ID (project number)
MESH_ID=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo "📊 Mesh ID (Project Number): $MESH_ID"
echo ""

# Obtém revisões do ASM
echo "🔍 Obtendo revisões do ASM..."
APP_ASM_REV=$(kubectl get deployment -n istio-system -l app=istiod --context=$APP_ENGINE_CTX -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "asm-managed")
MASTER_ASM_REV=$(kubectl get deployment -n istio-system -l app=istiod --context=$MASTER_ENGINE_CTX -o jsonpath='{.items[0].spec.template.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "asm-managed")

if [ -z "$APP_ASM_REV" ] || [ "$APP_ASM_REV" == "null" ]; then
    APP_ASM_REV="asm-managed"
fi

if [ -z "$MASTER_ASM_REV" ] || [ "$MASTER_ASM_REV" == "null" ]; then
    MASTER_ASM_REV="asm-managed"
fi

echo "   app-engine ASM revision: $APP_ASM_REV"
echo "   master-engine ASM revision: $MASTER_ASM_REV"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Função para obter o certificado CA do istiod
obter_ca_cert() {
    local context=$1
    local cluster_name=$2
    
    echo "   🔍 Obtendo certificado CA do cluster $cluster_name..." >&2
    
    # Tenta obter o pod istiod usando diferentes métodos
    ISTIOD_POD=$(kubectl get pods -n istio-system --context=$context -l app=istiod -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    # Se não encontrou, tenta buscar por nome
    if [ -z "$ISTIOD_POD" ]; then
        ISTIOD_POD=$(kubectl get pods -n istio-system --context=$context -o jsonpath='{.items[?(@.metadata.name=~"istiod.*")].metadata.name}' 2>/dev/null | awk '{print $1}' || echo "")
    fi
    
    # Se ainda não encontrou, lista todos os pods e filtra
    if [ -z "$ISTIOD_POD" ]; then
        ISTIOD_POD=$(kubectl get pods -n istio-system --context=$context -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -E "^istiod" | head -1 || echo "")
    fi
    
    # Se ainda não encontrou, tenta por deployment
    if [ -z "$ISTIOD_POD" ]; then
        ISTIOD_DEPLOY=$(kubectl get deployment -n istio-system --context=$context -o jsonpath='{range .items[?(@.metadata.name=~"istiod.*")]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1 || echo "")
        if [ -n "$ISTIOD_DEPLOY" ]; then
            ISTIOD_POD=$(kubectl get pods -n istio-system --context=$context -l app=$ISTIOD_DEPLOY -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$ISTIOD_POD" ]; then
        echo "   ❌ ERRO: Pod istiod não encontrado no cluster $cluster_name" >&2
        echo "   💡 Verificando pods disponíveis em istio-system..." >&2
        kubectl get pods -n istio-system --context=$context 2>/dev/null | head -5 >&2 || true
        echo "" >&2
        echo "   💡 Verifique se o ASM está instalado e os pods estão rodando:" >&2
        echo "      kubectl get pods -n istio-system --context=$context" >&2
        return 1
    fi
    
    echo "      Pod istiod encontrado: $ISTIOD_POD" >&2
    
    # Tenta obter o certificado de diferentes locais no pod istiod
    CA_CERT=$(kubectl exec -n istio-system --context=$context $ISTIOD_POD -c discovery -- cat /var/run/secrets/istio/root-cert.pem 2>/dev/null || \
              kubectl exec -n istio-system --context=$context $ISTIOD_POD -c istio-proxy -- cat /var/run/secrets/istio/root-cert.pem 2>/dev/null || \
              kubectl exec -n istio-system --context=$context $ISTIOD_POD -- cat /var/run/secrets/istio/root-cert.pem 2>/dev/null || echo "")
    
    if [ -z "$CA_CERT" ]; then
        echo "   ⚠️  Tentando obter certificado de secret..." >&2
        # Tenta obter de um secret
        CA_SECRET=$(kubectl get secrets -n istio-system --context=$context | grep istio | grep ca | head -1 | awk '{print $1}' || echo "")
        if [ -n "$CA_SECRET" ]; then
            CA_CERT=$(kubectl get secret -n istio-system --context=$context $CA_SECRET -o jsonpath='{.data.root-cert}' 2>/dev/null | base64 -d || echo "")
        fi
    fi
    
    # Se ainda não encontrou, tenta obter do cluster CA (fallback)
    if [ -z "$CA_CERT" ] || [ ${#CA_CERT} -lt 100 ]; then
        echo "   ⚠️  Tentando obter certificado do cluster Kubernetes CA..." >&2
        # Obtém o certificado CA do cluster como fallback
        CLUSTER_CA=$(kubectl config view --context=$context --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' 2>/dev/null | base64 -d || echo "")
        if [ -n "$CLUSTER_CA" ] && [ ${#CLUSTER_CA} -gt 100 ]; then
            CA_CERT="$CLUSTER_CA"
            echo "   ⚠️  Usando certificado CA do cluster Kubernetes (pode não ser o ideal para ASM)" >&2
        fi
    fi
    
    if [ -z "$CA_CERT" ] || [ ${#CA_CERT} -lt 100 ]; then
        echo "   ❌ ERRO: Não foi possível obter o certificado CA do cluster $cluster_name" >&2
        if [ -n "$ISTIOD_POD" ]; then
            echo "   💡 Tente manualmente:" >&2
            echo "      kubectl exec -n istio-system --context=$context $ISTIOD_POD -c discovery -- cat /var/run/secrets/istio/root-cert.pem" >&2
            echo "   ou" >&2
            echo "      kubectl exec -n istio-system --context=$context $ISTIOD_POD -- cat /var/run/secrets/istio/root-cert.pem" >&2
        fi
        return 1
    fi
    
    echo "   ✅ Certificado CA obtido com sucesso" >&2
    echo "$CA_CERT"
    return 0
}

# Atualiza os manifestos com os valores corretos
echo "📝 Preparando manifestos..."

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copia estrutura de diretórios
cp -r "$GATEWAY_DIR/app-engine" "$TEMP_DIR/"
cp -r "$GATEWAY_DIR/master-engine" "$TEMP_DIR/"

# Obtém certificados CA
echo ""
echo "🔐 Obtendo certificados CA dos clusters..."
APP_CA_CERT=$(obter_ca_cert $APP_ENGINE_CTX "app-engine")
if [ $? -ne 0 ]; then
    echo "❌ Falha ao obter certificado CA do app-engine"
    exit 1
fi

MASTER_CA_CERT=$(obter_ca_cert $MASTER_ENGINE_CTX "master-engine")
if [ $? -ne 0 ]; then
    echo "❌ Falha ao obter certificado CA do master-engine"
    exit 1
fi

echo ""

# Atualiza ConfigMaps com os certificados CA
echo "📝 Atualizando ConfigMaps com certificados CA..."
# Usa awk para substituir preservando a indentação YAML
# Substitui a linha que contém PLACEHOLDER_CA_CERT com o certificado, mantendo a indentação
cat > "$TEMP_DIR/app-engine/configmap-ca-cert.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-ca-root-cert
  namespace: istio-system
data:
  root-cert.pem: |
$(echo "$APP_CA_CERT" | sed 's/^/    /')
EOF

cat > "$TEMP_DIR/master-engine/configmap-ca-cert.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-ca-root-cert
  namespace: istio-system
data:
  root-cert.pem: |
$(echo "$MASTER_CA_CERT" | sed 's/^/    /')
EOF

# Atualiza gateway.yaml com MESH_ID e ASM_REVISION
echo "📝 Atualizando manifestos do gateway..."
sed -i.bak "s|MESH_ID|$MESH_ID|g" "$TEMP_DIR/app-engine/gateway.yaml"
sed -i.bak "s|asm-managed|$APP_ASM_REV|g" "$TEMP_DIR/app-engine/gateway.yaml"
sed -i.bak "s|MESH_ID|$MESH_ID|g" "$TEMP_DIR/master-engine/gateway.yaml"
sed -i.bak "s|asm-managed|$MASTER_ASM_REV|g" "$TEMP_DIR/master-engine/gateway.yaml"
rm "$TEMP_DIR/app-engine/gateway.yaml.bak" 2>/dev/null || true
rm "$TEMP_DIR/master-engine/gateway.yaml.bak" 2>/dev/null || true

echo "📦 Instalando gateway no cluster app-engine..."
kubectl apply -k "$TEMP_DIR/app-engine" --context=$APP_ENGINE_CTX

echo ""
echo "📦 Instalando gateway no cluster master-engine..."
kubectl apply -k "$TEMP_DIR/master-engine" --context=$MASTER_ENGINE_CTX

echo ""
echo "⏳ Aguardando gateways ficarem prontos (pode levar 2-5 minutos)..."
echo ""

# Aguarda deployments
for i in {1..30}; do
    APP_READY=$(kubectl get deployment -n istio-system istio-eastwestgateway --context=$APP_ENGINE_CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    MASTER_READY=$(kubectl get deployment -n istio-system istio-eastwestgateway --context=$MASTER_ENGINE_CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    
    if [ "$APP_READY" = "1" ] && [ "$MASTER_READY" = "1" ]; then
        echo "✅ Gateways prontos!"
        break
    fi
    sleep 10
    if [ $((i % 3)) -eq 0 ]; then
        echo "   ⏳ Aguardando... ($i/30)"
    fi
done

echo ""
echo "📊 Status dos gateways:"
echo ""
echo "Cluster app-engine:"
kubectl get svc,deployment -n istio-system --context=$APP_ENGINE_CTX -l istio=eastwestgateway

echo ""
echo "Cluster master-engine:"
kubectl get svc,deployment -n istio-system --context=$MASTER_ENGINE_CTX -l istio=eastwestgateway

echo ""
echo "💡 Aguarde alguns minutos para os IPs do LoadBalancer ficarem disponíveis."
echo "   Execute: kubectl get svc -n istio-system istio-eastwestgateway --context=<contexto>"
echo ""

