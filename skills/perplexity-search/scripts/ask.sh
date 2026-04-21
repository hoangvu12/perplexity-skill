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

request_body="$(jq -n \
  --arg model "$model" \
  --arg query "$query" \
  --arg recency "$recency" \
  --arg domains "$domains" \
  --arg search_mode "$search_mode" \
  --arg reasoning_effort "$reasoning_effort" \
  '{
    model: $model,
    messages: [
      {role: "system", content: "Be concise. Always cite sources."},
      {role: "user", content: $query}
    ],
    return_related_questions: true
  }
  + (if $recency != "" then {search_recency_filter: $recency} else {} end)
  + (if $domains != "" then {search_domain_filter: ($domains | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))} else {} end)
  + (if $search_mode != "" then {search_mode: $search_mode} else {} end)
  + (if $reasoning_effort != "" then {reasoning_effort: $reasoning_effort} else {} end)')"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

if ! http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X POST "https://api.perplexity.ai/chat/completions" -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" -H "Content-Type: application/json" -d "$request_body")"; then
  printf '%s\n' 'Perplexity request failed due to a network or curl error.' >&2
  exit 1
fi

if [[ "$http_code" != "200" ]]; then
  message="$(jq -r '.error.message // .message // empty' "$response_file")"
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
  jq '.' "$response_file"
  exit 0
fi

jq -r '
  .choices[0].message.content,
  "",
  (if (.citations // []) | length > 0 then "Sources:" else empty end),
  ((.citations // [])[] | "- " + .),
  (if (.related_questions // []) | length > 0 then "" else empty end),
  (if (.related_questions // []) | length > 0 then "Related:" else empty end),
  ((.related_questions // [])[] | "- " + .)
' "$response_file"
