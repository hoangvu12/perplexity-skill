#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/preflight.sh"

usage() {
  printf '%s\n' 'Usage: bash scripts/ask.sh "question" [--model sonar-pro] [--recency month] [--domains a,b] [--search-mode web] [--reasoning-effort medium] [--json]'
}

query=""
model=""
recency=""
domains=""
search_mode=""
reasoning_effort=""
raw_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      model="${2:-}"
      shift 2
      ;;
    --recency)
      recency="${2:-}"
      shift 2
      ;;
    --domains)
      domains="${2:-}"
      shift 2
      ;;
    --search-mode)
      search_mode="${2:-}"
      shift 2
      ;;
    --reasoning-effort)
      reasoning_effort="${2:-}"
      shift 2
      ;;
    --json)
      raw_json=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$query" ]]; then
        query="$1"
        shift
      else
        printf 'Unexpected argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$query" ]]; then
  usage >&2
  exit 1
fi

perplexity_preflight || exit_code=$?
if [[ -n "${exit_code:-}" ]]; then
  if [[ $exit_code -eq 2 ]]; then
    exit 2
  fi
  exit "$exit_code"
fi

model="${model:-${PERPLEXITY_DEFAULT_MODEL:-sonar-pro}}"
recency="${recency:-${PERPLEXITY_DEFAULT_RECENCY:-}}"

request_body="$(perplexity_python - "$model" "$query" "$recency" "$domains" "$search_mode" "$reasoning_effort" <<'PY'
import json
import sys

model, query, recency, domains, search_mode, reasoning_effort = sys.argv[1:7]

payload = {
    'model': model,
    'messages': [
        {'role': 'system', 'content': 'Be concise. Always cite sources.'},
        {'role': 'user', 'content': query},
    ],
    'return_related_questions': True,
}

if recency:
    payload['search_recency_filter'] = recency
if domains:
    values = [item.strip() for item in domains.split(',') if item.strip()]
    if values:
        payload['search_domain_filter'] = values
if search_mode:
    payload['search_mode'] = search_mode
if reasoning_effort:
    payload['reasoning_effort'] = reasoning_effort

sys.stdout.write(json.dumps(payload))
PY
)"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

if ! http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X POST "https://api.perplexity.ai/chat/completions" -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" -H "Content-Type: application/json" -d "$request_body")"; then
  printf '%s\n' 'Perplexity request failed due to a network or curl error.' >&2
  exit 1
fi

if [[ "$http_code" != "200" ]]; then
  message="$(perplexity_python - "$response_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as handle:
        data = json.load(handle)
except Exception:
    data = {}

message = ''
if isinstance(data.get('error'), dict):
    message = data['error'].get('message', '')
if not message:
    message = data.get('message', '') or ''

sys.stdout.write(str(message))
PY
)"
  case "$http_code" in
    401)
      printf '%s\n' 'Perplexity authentication failed. Re-save the key with bash scripts/save-key.sh <key>.' >&2
      ;;
    429)
      printf '%s\n' 'Perplexity rate limit reached. Retry with backoff.' >&2
      ;;
    *)
      if [[ -n "$message" ]]; then
        printf 'Perplexity request failed (%s): %s\n' "$http_code" "$message" >&2
      else
        printf 'Perplexity request failed with HTTP %s.\n' "$http_code" >&2
      fi
      ;;
  esac
  exit 1
fi

if [[ $raw_json -eq 1 ]]; then
  perplexity_python -m json.tool "$response_file"
  exit 0
fi

perplexity_python - "$response_file" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

message = ''
choices = data.get('choices') or []
if choices:
    message = ((choices[0].get('message') or {}).get('content')) or ''

print(message)

citations = data.get('citations') or []
if citations:
    print()
    print('Sources:')
    for citation in citations:
        print(f'- {citation}')

related = data.get('related_questions') or []
if related:
    print()
    print('Related:')
    for item in related:
        print(f'- {item}')
PY
