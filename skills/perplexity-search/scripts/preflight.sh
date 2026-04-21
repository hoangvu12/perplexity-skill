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

perplexity_resolve_python() {
  if [[ -n "${PERPLEXITY_PYTHON_BIN:-}" && -x "${PERPLEXITY_PYTHON_BIN}" ]]; then
    printf '%s' "$PERPLEXITY_PYTHON_BIN"
    return 0
  fi

  local candidate
  for candidate in python python3 py; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 1
}

perplexity_python() {
  local python_bin
  python_bin="$(perplexity_resolve_python)" || {
    printf '%s\n' 'Missing required command: python' >&2
    return 1
  }

  "$python_bin" "$@"
}

perplexity_json_get() {
  local json_file="$1"
  local key="$2"

  perplexity_python - "$json_file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r', encoding='utf-8') as handle:
        value = json.load(handle).get(key, '')
except FileNotFoundError:
    value = ''
except Exception:
    value = ''

if value is None:
    value = ''

sys.stdout.write(str(value))
PY
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

  export PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-$(perplexity_json_get "$PERPLEXITY_CONFIG_FILE" api_key)}"
  export PERPLEXITY_DEFAULT_MODEL="${PERPLEXITY_DEFAULT_MODEL:-$(perplexity_json_get "$PERPLEXITY_CONFIG_FILE" default_model)}"
  export PERPLEXITY_DEFAULT_RECENCY="${PERPLEXITY_DEFAULT_RECENCY:-$(perplexity_json_get "$PERPLEXITY_CONFIG_FILE" default_recency)}"
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
  perplexity_resolve_python >/dev/null || {
    printf '%s\n' 'Missing required command: python' >&2
    return 1
  }

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
