# Screenshots / GIFs

Captures from the standalone box we actually ran. The [README](../../README.md) embeds these on the exact paths below. Nothing here is a cluster screenshot, a real API key, or a claim that MCP is wired.

## Stills

| File | What |
| --- | --- |
| `harness-settings.png` | Settings → Models list. DeepSeek red, custom agentgateway green |
| `harness-settings-detail.png` | Custom provider: base URL `http://127.0.0.1:4002/v1`, API `openai-completions`, dummy key already set |
| `harness-models-max-tokens.png` | Customized model catalog — `gpt-4o` max output tokens **8192** |
| `harness-model-picker.png` | Harness http://127.0.0.1:3080 — model picker, `gpt-4o` on `agentgateway (OpenAI via dummy token)` |
| `harness-run.png` | Two-question chat: `4` and `Paris` |
| `agw-ui.png` | agentgateway Analytics http://127.0.0.1:14010/ui — 39 tokens / 2 calls |
| `agw-logs.png` | agentgateway Logs — two `CHAT` / `200` rows |

## Clips

| File | What |
| --- | --- |
| `harness-run.gif` | New Session, pick agentgateway / `gpt-4o`, a turn |
| `agw-costs.gif` | Admin UI — Analytics and cost totals for the run |

The README uses them in step order: `harness-run.gif` up top → Settings → Models list → provider detail → max tokens → picker → run → Analytics + `agw-costs.gif` + Logs.
