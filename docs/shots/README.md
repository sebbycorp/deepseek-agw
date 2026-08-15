# Screenshots / GIFs

Standalone stills from the box we actually ran. Names below are the reserved paths the README embeds. Drop the PNG captures on these exact names. Nothing here is a cluster screenshot, a real API key, or a claim that MCP is wired.

| File | What |
| --- | --- |
| `harness-model-picker.png` | Harness http://127.0.0.1:3080 — model picker, `gpt-4o` on `agentgateway (OpenAI via dummy token)` |
| `harness-settings.png` | Settings → Models list. DeepSeek red, custom agentgateway green |
| `harness-settings-detail.png` | Custom provider: base URL `http://127.0.0.1:4002/v1`, API `openai-completions`, dummy key already set |
| `harness-models-max-tokens.png` | Customized model catalog — `gpt-4o` max output tokens **8192** |
| `harness-run.png` | Two-question chat: `4` and `Paris` |
| `agw-ui.png` | agentgateway Analytics http://127.0.0.1:14010/ui — 39 tokens / 2 calls |
| `agw-logs.png` | agentgateway Logs — two `CHAT` / `200` rows |

The README configure section embeds these in order: picker → Models list → provider detail → max tokens → run → Analytics + Logs.

## GIF placeholders

Not recorded this launch. Drop clips here if you have them:

| File | What |
| --- | --- |
| `harness-run.gif` | New Session, pick agentgateway / `gpt-4o`, a turn |
| `agw-costs.gif` | http://127.0.0.1:14010/ui/llm/costs |
