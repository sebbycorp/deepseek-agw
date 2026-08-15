# Same thing on Kubernetes

The standalone setup is the [main README](../README.md) — that is what we actually ran. This page is the same pattern on a cluster: Harness talks OpenAI-compat with a dummy token, and the real OpenAI key lives only in a Kubernetes Secret on the gateway. Cost catalog and traces stay on the gateway.

The manifests are files in [`k8s/`](../k8s/), not snippets on this page. See [`k8s/README.md`](../k8s/README.md) for the file-by-file map.

> **Untested.** No cluster was stood up for this repo, so there are no screenshots here. The CRDs mirror the official agentgateway Kubernetes docs (1.4.x): `Secret`, `AgentgatewayBackend`, `HTTPRoute`, `AgentgatewayParameters`, `AgentgatewayPolicy`.

## Before you begin

- A cluster, `kubectl`, and `helm`. Kind is enough: `kind create cluster`.
- `agctl`, for the cost catalog import.
- Your OpenAI key in `$OPENAI_API_KEY` or the same mode-600 `.secrets/openai.env` that `start-agw.sh` uses.

## Step 1: Install

```bash
./k8s/install.sh
```

That script pins **v1.4.1** and does every step below in order: Gateway API CRDs, the agentgateway CRD and controller charts, the Secret, the cost-catalog ConfigMap, then `k8s/*.yaml`. Prefer to run it by hand? The commands are in [`k8s/README.md`](../k8s/README.md#install).

Two things are built at install time and never committed:

| Not in git | Why | Where it comes from |
| --- | --- | --- |
| `openai-secret` | Real key | `kubectl create secret ... --from-literal=Authorization="$OPENAI_API_KEY"` |
| `openai-costs` ConfigMap | Generated | `agctl costs import --source models.dev --providers openai` |

## Step 2: Point Harness at the gateway

```bash
kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 8080:80
export GATEWAY_API_KEY=local-harness-not-openai
npx @deepseek-ai/dsh web
```

Provider `agw`, api `openai-completions`, baseURL `http://127.0.0.1:8080/v1`. In-cluster, the same dummy token against `http://agentgateway-proxy.agentgateway-system.svc/v1`. There is no `dsh` Deployment in this repo.

The full UI walkthrough — provider form, model catalog, the `maxTokens` gotcha, picking `agw` instead of `deepseek-official` — is [Step 6 of the main README](../README.md#step-6-point-harness-at-the-gateway). Same form, same gotchas; only the base URL differs.

## What's different from standalone

| | Standalone | Kubernetes |
| --- | --- | --- |
| Real key | mode-600 `.secrets/openai.env` | `openai-secret` Secret, `Authorization` key |
| Config | [`agentgateway.yaml`](../agentgateway.yaml) | [`k8s/*.yaml`](../k8s/) CRDs |
| Cost catalog | `config.modelCatalog` → local file | ConfigMap + `AgentgatewayParameters` on the **Gateway** (a GatewayClass catalog is ignored) |
| Harness base URL | `http://127.0.0.1:4002/v1` | `http://127.0.0.1:8080/v1` (port-forward) |
| Admin UI | `http://127.0.0.1:14010/ui` | port-forward `15000` → `http://127.0.0.1:15000/ui` |
| Jaeger | `docker run` all-in-one | [`k8s/00-jaeger.yaml`](../k8s/00-jaeger.yaml), port-forward `16686` |

## Where to look

Ports are the controller defaults, not standalone `14010` / `4002`.

| What | Where |
| --- | --- |
| Harness UI | <http://127.0.0.1:3080> |
| OpenAI-compat | `http://127.0.0.1:8080/v1` (port-forward `deploy/agentgateway-proxy 8080:80`) |
| Admin UI | `kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 15000` → <http://127.0.0.1:15000/ui> |
| Jaeger | `kubectl port-forward -n telemetry svc/jaeger-ui 16686:16686` → <http://127.0.0.1:16686> |

No real key in git. No Secret manifests. No cluster screenshots. MCP is not wired.
