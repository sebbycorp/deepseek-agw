# deepseek-agw

This is the setup we actually ran: **standalone** agentgateway in front of local DeepSeek Harness.

`dsh` is a local agent UI. I put the gateway in the middle so the UI never sees the real OpenAI key. Harness talks to `http://127.0.0.1:4002/v1` with a dummy token. The gateway is the only process that holds `OPENAI_API_KEY`. Token stats, USD cost, and Jaeger traces live there.

Same pattern later for MCP — not wired in this first pass. Same pattern on Kubernetes is a shorter follow-up, not this story: [docs/kubernetes.md](docs/kubernetes.md).

## Architecture

```mermaid
flowchart LR
  dsh["dsh web :3080"] -->|"dummy token /v1"| agw["agentgateway :4002"]
  agw -->|"real OPENAI_API_KEY"| openai[OpenAI]
  agw --> admin["admin UI :14010"]
  agw --> jaeger["Jaeger :16686"]
```

The key is not in GitHub, not in `$DSH_HOME`, and not in the harness process. A mode-600 file is sourced by `start-agw.sh` and exported into the gateway process only. Sample config is [`agentgateway.yaml`](agentgateway.yaml) — `$OPENAI_API_KEY` placeholder, no secret.

## Commands

This is what I typed on the box. agentgateway **1.4.1**. Node **24** — Node 20 is too old for current `dsh`.

Node 24:

```
nvm install 24
nvm use 24
node -v
```

Gateway + `agctl`, pinned:

```
curl -sL https://agentgateway.dev/install | bash -s -- --version v1.4.1
agentgateway --version
```

Cost catalog (once). Lands in `config.modelCatalog`:

```
mkdir -p costs
agctl costs import --source models.dev --providers openai --out ./costs/catalog.json
```

Jaeger all-in-one:

```
docker run -d --name jaeger \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  jaegertracing/all-in-one:latest
```

Real key in a 600 file. Do not commit it. Do not put it in the yaml.

```
mkdir -p .secrets
umask 077
printf 'export OPENAI_API_KEY=sk-...\n' > .secrets/openai.env
chmod 600 .secrets/openai.env
```

Start the gateway. `OPENAI_API_KEY` is in this process only.

```
./start-agw.sh
```

Admin UI: http://127.0.0.1:14010/ui · costs: http://127.0.0.1:14010/ui/llm/costs · LLM listener `:4002` · metrics `:14030`.

Harness, dummy token — not the OpenAI key:

```
export GATEWAY_API_KEY=local-harness-not-openai
npx @deepseek-ai/dsh web
```

UI is http://127.0.0.1:3080. Pointing harness at the gateway is the next section. Required.

## Configure DeepSeek Harness with agentgateway

This is the wiring. Skip it and the first turn hits `deepseek-official` with no `DEEPSEEK_API_KEY`, or `gpt-4o` with `maxTokens` 32768 and a 400.

Gateway is already up. Real OpenAI key is only in the agentgateway process env. Confirm the admin UI at http://127.0.0.1:14010/ui and the costs page at http://127.0.0.1:14010/ui/llm/costs before you touch harness.

### UI — http://127.0.0.1:3080

1. Open the harness UI.
2. **Settings → Models**.
3. **Add a custom provider**, or use the `agw` provider if it is already in `$DSH_HOME/settings.yaml`.
4. Fill the form:
   - Provider ID: `agw`
   - API: `openai-completions`
   - baseURL: `http://127.0.0.1:4002/v1`
   - apiKeyEnv: `GATEWAY_API_KEY`
   - Key value: `local-harness-not-openai` — **not** the real OpenAI key
5. Add models. At least `gpt-4o` and `gpt-4o-mini`. Set **maxTokens to 16384** (or 8192). The harness default is 32768. That default makes `gpt-4o` return 400 (max completion tokens 16384).
6. **New Session**. Pick **agentgateway / gpt-4o** (`agw`). Do not pick `deepseek-official`.

### Files — `$DSH_HOME` (usually `~/.dsh`)

The UI writes here. You can edit the same files by hand.

`$DSH_HOME/settings.yaml` — provider and model caps. No OpenAI key.

```
llm-pi-ai:
  providers:
    agw:
      apiKeyEnv: GATEWAY_API_KEY
      api: openai-completions
      baseURL: http://127.0.0.1:4002/v1
      models:
        - id: gpt-4o
          maxTokens: 16384
        - id: gpt-4o-mini
          maxTokens: 16384
```

`$DSH_HOME/.credentials.yaml` — dummy token only. The Models page stores `GATEWAY_API_KEY` = `local-harness-not-openai` here (write-only in the UI). That is not `OPENAI_API_KEY`. Do not put the real key in `$DSH_HOME`.

If you exported `GATEWAY_API_KEY` before `npx @deepseek-ai/dsh web`, harness can resolve the env instead. Same dummy. Same rule.

## The one gotcha

1. Default `maxTokens` is 32768. `gpt-4o` returns **400** above 16384 completion tokens. Use 16384 or 8192.
2. First UI turn used `deepseek-official`. There is no `DEEPSEEK_API_KEY` here. **New Session** → `agw` / `gpt-4o`.

## Where to look

- Harness UI: http://127.0.0.1:3080
- Harness settings: `$DSH_HOME/settings.yaml` (usually `~/.dsh/settings.yaml`)
- Harness dummy token: `$DSH_HOME/.credentials.yaml` — dummy only
- agentgateway admin: http://127.0.0.1:14010/ui
- Costs: http://127.0.0.1:14010/ui/llm/costs
- Jaeger: http://127.0.0.1:16686
- OpenAI-compat listener: http://127.0.0.1:4002/v1
- Metrics: http://127.0.0.1:14030

## Screenshots / GIFs

Not in the repo yet. Drop files on these paths in a follow-up:

- `docs/shots/harness-settings.png` — Settings → Models, `agw` provider
- `docs/shots/agw-ui.png` — agentgateway admin http://127.0.0.1:14010/ui
- `docs/shots/harness-run.gif` — New Session, `agw` / `gpt-4o`, a turn
- `docs/shots/agw-costs.gif` — http://127.0.0.1:14010/ui/llm/costs

![Harness Settings → Models](docs/shots/harness-settings.png)

![agentgateway admin UI](docs/shots/agw-ui.png)

![Harness run](docs/shots/harness-run.gif)

![agentgateway costs](docs/shots/agw-costs.gif)

Standalone only. No cluster screenshots.

## What this is not

MCP is not wired. Same gateway pattern later. The sample yaml has `$OPENAI_API_KEY` only — no real key in this repo. Kubernetes is the same idea with a Secret instead of a 600 file; that page is shorter on purpose.
