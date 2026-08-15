# Kubernetes manifests

The same pattern as the standalone [README](../README.md), as files you can apply. Harness talks OpenAI-compat with a dummy token; the real OpenAI key lives only in a Kubernetes Secret on the gateway.

> **Untested.** No cluster was stood up for this repo — the standalone path is the one we actually ran. These manifests mirror the CRDs in the official agentgateway Kubernetes docs (1.4.x) and the walkthrough in [../docs/kubernetes.md](../docs/kubernetes.md). Expect to adjust field names if you are on a different version.

## Files

| File | What | Standalone equivalent in [`agentgateway.yaml`](../agentgateway.yaml) |
| --- | --- | --- |
| [`00-jaeger.yaml`](00-jaeger.yaml) | Jaeger all-in-one — Namespace, Deployment, OTLP + UI Services | the `docker run` in Step 3 |
| [`10-gateway.yaml`](10-gateway.yaml) | `AgentgatewayParameters` (cost catalog) + `Gateway` | `config.modelCatalog`, `gateways.default` |
| [`20-openai-backend.yaml`](20-openai-backend.yaml) | `AgentgatewayBackend` (OpenAI + auth) + `HTTPRoute` for `/v1` | `llm.models` |
| [`30-tracing-policy.yaml`](30-tracing-policy.yaml) | `AgentgatewayPolicy` — traces to Jaeger | `config.tracing` |
| [`install.sh`](install.sh) | Everything below, in order | [`start-agw.sh`](../start-agw.sh) |

## Not in this repo

Two things are generated at install time, never committed:

- **The Secret.** The real OpenAI key goes in `openai-secret` under the `Authorization` key, created from your shell. There is no Secret manifest here on purpose.
- **The cost catalog.** `costs/catalog.json` comes from `agctl costs import` and is gitignored. It becomes the `openai-costs` ConfigMap.

## Install

Scripted — reuses the same mode-600 key file as `start-agw.sh`:

```bash
./k8s/install.sh
```

Or by hand. Order matters: the ConfigMap must exist before the Gateway that references it, and the Secret before the backend.

```bash
export GWAPI_VERSION=1.6.0
kubectl apply --server-side --force-conflicts \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v$GWAPI_VERSION/standard-install.yaml

helm upgrade -i agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --create-namespace --namespace agentgateway-system --version v1.4.1
helm upgrade -i agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --namespace agentgateway-system --version v1.4.1 --wait

kubectl -n agentgateway-system create secret generic openai-secret \
  --from-literal=Authorization="$OPENAI_API_KEY"

agctl costs import --source models.dev --providers openai --out ./costs/catalog.json
kubectl -n agentgateway-system create configmap openai-costs \
  --from-file=catalog.json=./costs/catalog.json

kubectl apply -f k8s/
```

## Connect Harness

```bash
kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 8080:80
export GATEWAY_API_KEY=local-harness-not-openai
npx @deepseek-ai/dsh web
```

Provider `agw`, api `openai-completions`, baseURL `http://127.0.0.1:8080/v1`. In-cluster, the same dummy token against `http://agentgateway-proxy.agentgateway-system.svc/v1`. There is no `dsh` Deployment in this repo.

The UI walkthrough — provider form, model caps, the `maxTokens` gotcha — is [Step 6 of the main README](../README.md#step-6-point-harness-at-the-gateway). Only the base URL differs.

## Notes

- **Ports are the controller defaults**, not the standalone `14010` / `4002`. Admin UI: `kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 15000` → <http://127.0.0.1:15000/ui>. Jaeger: `kubectl port-forward -n telemetry svc/jaeger-ui 16686:16686`.
- **The cost catalog must be attached to the Gateway** via `AgentgatewayParameters`. A GatewayClass-level catalog is ignored.
- **The tracing policy points across namespaces** (`agentgateway-system` → `telemetry`). If traces never arrive, check whether your version wants a `ReferenceGrant` in `telemetry` for that reference.
- **Governance is standalone-only in this repo.** [`agentgateway-governed.yaml`](../agentgateway-governed.yaml) adds virtual keys, a token rate limit, and prompt guards to the local setup ([Step 8](../README.md#step-8-turn-on-governance)). The cluster equivalents are fields on `AgentgatewayPolicy` rather than another file here — I haven't run them, so rather than ship manifests I can't vouch for, start from the upstream policy reference.
- **MCP is not wired**, here or standalone.
