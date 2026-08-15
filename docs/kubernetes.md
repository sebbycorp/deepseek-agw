# Same thing on Kubernetes

Not the first pass. Standalone is the [README](../README.md) — that is what we actually ran. Same pattern: harness talks OpenAI-compat with a dummy token. The real OpenAI key lives only in a Kubernetes Secret on the gateway. Cost catalog and traces stay on the gateway. Harness can stay on your laptop (port-forward) or run in-cluster against the gateway Service. MCP later — not wired. I did not stand a cluster up for this repo. No screenshots. CRDs are from the official agentgateway Kubernetes docs (1.4.x): `Secret`, `AgentgatewayBackend`, `HTTPRoute`, `AgentgatewayParameters`, `AgentgatewayPolicy`.

## Commands

Pin **v1.4.1**. Need a cluster, `kubectl`, `helm`. Kind is enough: `kind create cluster`.

```
export GWAPI_VERSION=1.6.0
kubectl apply --server-side --force-conflicts \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v$GWAPI_VERSION/standard-install.yaml
helm upgrade -i agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --create-namespace --namespace agentgateway-system --version v1.4.1
helm upgrade -i agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --namespace agentgateway-system --version v1.4.1 --wait
```

Key in a Secret, from your shell, not from a file in git. Official key name is `Authorization`.

```
kubectl -n agentgateway-system create secret generic openai-secret \
  --from-literal=Authorization="$OPENAI_API_KEY"
```

Backend + `/v1` route (what harness calls):

```
kubectl apply -f- <<EOF
apiVersion: agentgateway.dev/v1alpha1
kind: AgentgatewayBackend
metadata: { name: openai, namespace: agentgateway-system }
spec:
  ai:
    provider: { openai: {} }
  policies:
    auth:
      secretRef: { name: openai-secret }
    ai:
      routes: { "/v1/chat/completions": Completions, "/v1/models": Models, "*": Passthrough }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: openai, namespace: agentgateway-system }
spec:
  parentRefs: [{ name: agentgateway-proxy, namespace: agentgateway-system }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /v1 } }]
      backendRefs: [{ name: openai, group: agentgateway.dev, kind: AgentgatewayBackend }]
EOF
```

Cost catalog: same `agctl` import as the README, then a ConfigMap. Attach with `AgentgatewayParameters` on the **Gateway** — a GatewayClass catalog is ignored.

```
agctl costs import --source models.dev --providers openai --out ./costs/catalog.json
kubectl -n agentgateway-system create configmap openai-costs \
  --from-file=catalog.json=./costs/catalog.json
kubectl apply -f- <<EOF
apiVersion: agentgateway.dev/v1alpha1
kind: AgentgatewayParameters
metadata: { name: openai-costs, namespace: agentgateway-system }
spec:
  modelCatalog:
    sources: [{ configMap: { name: openai-costs, key: catalog.json } }]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: agentgateway-proxy, namespace: agentgateway-system }
spec:
  gatewayClassName: agentgateway
  infrastructure:
    parametersRef: { name: openai-costs, group: agentgateway.dev, kind: AgentgatewayParameters }
  listeners:
    - { name: http, port: 80, protocol: HTTP, allowedRoutes: { namespaces: { from: All } } }
EOF
```

Tracing: Jaeger all-in-one, then `AgentgatewayPolicy` on the Gateway.

```
kubectl create namespace telemetry
kubectl -n telemetry create deploy jaeger --image=jaegertracing/all-in-one:latest
kubectl -n telemetry set env deploy/jaeger COLLECTOR_OTLP_ENABLED=true
kubectl -n telemetry expose deploy jaeger --port=4317 --target-port=4317 --name=jaeger
kubectl -n telemetry expose deploy jaeger --port=16686 --target-port=16686 --name=jaeger-ui
kubectl apply -f- <<EOF
apiVersion: agentgateway.dev/v1alpha1
kind: AgentgatewayPolicy
metadata: { name: tracing, namespace: agentgateway-system }
spec:
  targetRefs: [{ kind: Gateway, name: agentgateway-proxy, group: gateway.networking.k8s.io }]
  frontend:
    tracing:
      backendRef: { name: jaeger, namespace: telemetry, port: 4317 }
      protocol: GRPC
      randomSampling: "true"
EOF
```

Local harness. Dummy token. Full UI + `$DSH_HOME` walkthrough is **Configure DeepSeek Harness with agentgateway** in the README — same form, baseURL is the port-forward. Same `maxTokens` / pick-`agw` gotcha.

```
kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 8080:80
export GATEWAY_API_KEY=local-harness-not-openai
npx @deepseek-ai/dsh web
```

Provider `agw`, api `openai-completions`, baseURL `http://127.0.0.1:8080/v1`. In-cluster: same dummy against `http://agentgateway-proxy.agentgateway-system.svc/v1`. No dsh Deployment in this repo.

## Where to look

K8s ports are the controller defaults, not standalone `14010` / `4002`. Harness http://127.0.0.1:3080 · OpenAI-compat http://127.0.0.1:8080/v1 · admin `kubectl port-forward -n agentgateway-system deploy/agentgateway-proxy 15000` → http://127.0.0.1:15000/ui · Jaeger `kubectl port-forward -n telemetry deploy/jaeger 16686:16686` → http://127.0.0.1:16686. No real key in git. No Secret manifests. No cluster screenshots. MCP is not wired.
