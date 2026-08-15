#!/usr/bin/env bash
# Install agentgateway on Kubernetes and apply the manifests next to this script.
#
# Same shape as ../start-agw.sh: the real OpenAI key comes from a mode-600 file
# (or the env) and is handed straight to the cluster as a Secret. It is never
# written to a manifest in this repo.
#
#   ./k8s/install.sh
#
# Env overrides:
#   AGW_VERSION       agentgateway chart version   (default v1.4.1)
#   GWAPI_VERSION     Gateway API version          (default 1.6.0)
#   NAMESPACE         gateway namespace            (default agentgateway-system)
#   AGW_SECRET_FILE   key file                     (default ../.secrets/openai.env)
#   SKIP_TRACING=1    skip Jaeger and the tracing policy
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

AGW_VERSION="${AGW_VERSION:-v1.4.1}"
GWAPI_VERSION="${GWAPI_VERSION:-1.6.0}"
NAMESPACE="${NAMESPACE:-agentgateway-system}"
SECRET="${AGW_SECRET_FILE:-$ROOT/.secrets/openai.env}"

for bin in kubectl helm; do
  command -v "$bin" >/dev/null || { echo "missing $bin" >&2; exit 1; }
done

# Real key: env first, else the 600 file. Same file start-agw.sh uses.
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  if [[ ! -f "$SECRET" ]]; then
    echo "missing $SECRET and OPENAI_API_KEY is unset" >&2
    echo "create it with mode 600 and one line: export OPENAI_API_KEY=..." >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  set -a; . "$SECRET"; set +a
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is empty" >&2
  exit 1
fi

echo "==> Gateway API $GWAPI_VERSION"
kubectl apply --server-side --force-conflicts \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v$GWAPI_VERSION/standard-install.yaml"

echo "==> agentgateway $AGW_VERSION"
helm upgrade -i agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --create-namespace --namespace "$NAMESPACE" --version "$AGW_VERSION"
helm upgrade -i agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --namespace "$NAMESPACE" --version "$AGW_VERSION" --wait

# Secret, built in memory from the key above. Never rendered to a file in git.
echo "==> openai-secret (key: Authorization)"
kubectl -n "$NAMESPACE" create secret generic openai-secret \
  --from-literal=Authorization="$OPENAI_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Cost catalog. Generated, gitignored, same import as the standalone README.
CATALOG="$ROOT/costs/catalog.json"
if [[ ! -f "$CATALOG" ]]; then
  command -v agctl >/dev/null || { echo "missing agctl, needed to build $CATALOG" >&2; exit 1; }
  echo "==> importing cost catalog"
  mkdir -p "$ROOT/costs"
  agctl costs import --source models.dev --providers openai --out "$CATALOG"
fi
echo "==> openai-costs ConfigMap"
kubectl -n "$NAMESPACE" create configmap openai-costs \
  --from-file=catalog.json="$CATALOG" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> manifests"
if [[ "${SKIP_TRACING:-0}" != "1" ]]; then
  kubectl apply -f "$HERE/00-jaeger.yaml"
fi
kubectl apply -f "$HERE/10-gateway.yaml"
kubectl apply -f "$HERE/20-openai-backend.yaml"
if [[ "${SKIP_TRACING:-0}" != "1" ]]; then
  kubectl apply -f "$HERE/30-tracing-policy.yaml"
fi

cat <<EOF

Done. Point DeepSeek Harness at the gateway:

  kubectl port-forward -n $NAMESPACE deploy/agentgateway-proxy 8080:80
  export GATEWAY_API_KEY=local-harness-not-openai
  npx @deepseek-ai/dsh web

Provider 'agw', api 'openai-completions', baseURL http://127.0.0.1:8080/v1
Full UI walkthrough: Step 6 of ../README.md
EOF
