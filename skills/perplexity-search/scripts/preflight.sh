#!/usr/bin/env bash
set -euo pipefail

PERPLEXITY_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERPLEXITY_CONFIG_DIR="${HOME}/.config/perplexity"
PERPLEXITY_CONFIG_FILE="${PERPLEXITY_CONFIG_DIR}/config.json"
PERPLEXITY_LEGACY_KEY_FILE="${HOME}/.perplexity"

perplexity_emit_auth_required() {
  printf '%s\n' 'PERPLEXITY_AUTH_REQUIRED'
  printf '%s\n' 'Get a key at https://perplexity.ai/settings/api'
  printf '%s\n' "Then run: bash ${PERPLEXITY_SKILL_DIR}/scripts/save-key.sh <your-key>"
}

perplexity_require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    return 1
  fi
}

perplexity_strip_wrapping_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

perplexity_load_dotenv() {
  local dotenv_path="$1"
  local line key value

  [[ -f "$dotenv_path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#export }"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    value="$(perplexity_strip_wrapping_quotes "$value")"

    case "$key" in
      PERPLEXITY_API_KEY)
        export PERPLEXITY_API_KEY="$value"
        ;;
      PERPLEXITY_DEFAULT_MODEL)
        export PERPLEXITY_DEFAULT_MODEL="$value"
        ;;
      PERPLEXITY_DEFAULT_RECENCY)
        export PERPLEXITY_DEFAULT_RECENCY="$value"
        ;;
    esac
  done < "$dotenv_path"
}

perplexity_load_json_config() {
  [[ -f "$PERPLEXITY_CONFIG_FILE" ]] || return 0

  export PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-$(jq -r '.api_key // empty' "$PERPLEXITY_CONFIG_FILE")}"
  export PERPLEXITY_DEFAULT_MODEL="${PERPLEXITY_DEFAULT_MODEL:-$(jq -r '.default_model // empty' "$PERPLEXITY_CONFIG_FILE")}"
  export PERPLEXITY_DEFAULT_RECENCY="${PERPLEXITY_DEFAULT_RECENCY:-$(jq -r '.default_recency // empty' "$PERPLEXITY_CONFIG_FILE")}"
}

perplexity_load_legacy_key() {
  [[ -f "$PERPLEXITY_LEGACY_KEY_FILE" ]] || return 0
  export PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-$(tr -d '\r\n' < "$PERPLEXITY_LEGACY_KEY_FILE")}"
}

perplexity_validate_key_format() {
  [[ -n "${PERPLEXITY_API_KEY:-}" && "${PERPLEXITY_API_KEY}" =~ ^pplx-[A-Za-z0-9._-]+$ ]]
}

perplexity_preflight() {
  perplexity_require_command curl
  perplexity_require_command jq

  if perplexity_validate_key_format; then
    return 0
  fi

  perplexity_load_dotenv "${PWD}/.env"
  if perplexity_validate_key_format; then
    return 0
  fi

  perplexity_load_json_config
  if perplexity_validate_key_format; then
    return 0
  fi

  perplexity_load_legacy_key
  if perplexity_validate_key_format; then
    return 0
  fi

  perplexity_emit_auth_required
  return 2
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  perplexity_preflight
fi
