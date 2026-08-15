#!/usr/bin/env bash
# Start standalone agentgateway. The real OpenAI key stays in a 600 file
# and is exported into this process only. Do not commit that file.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SECRET="${AGW_SECRET_FILE:-$ROOT/.secrets/openai.env}"

if [[ ! -f "$SECRET" ]]; then
  echo "missing $SECRET" >&2
  echo "create it with mode 600 and one line: export OPENAI_API_KEY=..." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
# source the 600 file
. "$SECRET"
set +a

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is empty after sourcing $SECRET" >&2
  exit 1
fi

# Which config to run. Default is the plain one; the governed config adds
# virtual keys, a rate limit, and prompt guards.
#   AGW_CONFIG=./agentgateway-governed.yaml ./start-agw.sh
CONFIG="${AGW_CONFIG:-$ROOT/agentgateway.yaml}"

if [[ ! -f "$CONFIG" ]]; then
  echo "missing config $CONFIG" >&2
  exit 1
fi

# Any $VAR the config expects must exist, or agentgateway starts with an
# empty credential and every request fails in a way that looks like a
# Harness problem. Check up front instead.
while read -r var; do
  if [[ -z "${!var:-}" ]]; then
    echo "$CONFIG needs \$$var, which is empty after sourcing $SECRET" >&2
    echo "add it to that file, e.g. export $var=sk-dsh-..." >&2
    exit 1
  fi
done < <(grep -oE '\$[A-Z][A-Z0-9_]+' "$CONFIG" | tr -d '$' | sort -u)

exec agentgateway -f "$CONFIG"
