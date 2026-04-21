#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/preflight.sh"

usage() {
  printf '%s\n' 'Usage: bash scripts/save-key.sh <pplx-key> [--model sonar-pro] [--recency month]'
}

api_key=""
default_model="sonar-pro"
default_recency=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      default_model="${2:-}"
      shift 2
      ;;
    --recency)
      default_recency="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$api_key" ]]; then
        api_key="$1"
        shift
      else
        printf 'Unexpected argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$api_key" ]]; then
  usage >&2
  exit 1
fi

if [[ ! "$api_key" =~ ^pplx-[A-Za-z0-9._-]+$ ]]; then
  printf '%s\n' 'Invalid key format. Expected a value starting with pplx-.' >&2
  exit 1
fi

perplexity_require_command curl
perplexity_require_command jq

probe_body="$(jq -n '{model:"sonar",messages:[{role:"user",content:"Reply with the single word ok."}],max_tokens:16,disable_search:true}')"
probe_file="$(mktemp)"
trap 'rm -f "$probe_file"' EXIT

if ! http_code="$(curl -sS -o "$probe_file" -w "%{http_code}" -X POST "https://api.perplexity.ai/chat/completions" -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" -d "$probe_body")"; then
  printf '%s\n' 'Perplexity probe failed due to a network or curl error.' >&2
  exit 1
fi

case "$http_code" in
  200)
    ;;
  401)
    printf '%s\n' 'Perplexity rejected the key with 401 Unauthorized.' >&2
    exit 1
    ;;
  *)
    message="$(jq -r '.error.message // .message // empty' "$probe_file")"
    if [[ -n "$message" ]]; then
      printf 'Perplexity probe failed (%s): %s\n' "$http_code" "$message" >&2
    else
      printf 'Perplexity probe failed with HTTP %s.\n' "$http_code" >&2
    fi
    exit 1
    ;;
esac

mkdir -p "$PERPLEXITY_CONFIG_DIR"

config_json="$(jq -n --arg api_key "$api_key" --arg default_model "$default_model" --arg default_recency "$default_recency" '{api_key:$api_key,default_model:$default_model} + (if $default_recency != "" then {default_recency:$default_recency} else {} end)')"
printf '%s\n' "$config_json" > "$PERPLEXITY_CONFIG_FILE"
chmod 600 "$PERPLEXITY_CONFIG_FILE" 2>/dev/null || true

printf 'Saved Perplexity config to %s\n' "$PERPLEXITY_CONFIG_FILE"
