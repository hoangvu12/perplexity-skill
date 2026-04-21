#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -t 0 ]]; then
  printf '%s\n' 'setup.sh requires an interactive terminal.' >&2
  exit 1
fi

printf '%s\n' 'Create a Perplexity API key at https://perplexity.ai/settings/api'
printf '%s' 'Perplexity API key: '
IFS= read -r -s api_key
printf '\n'

if [[ -z "$api_key" ]]; then
  printf '%s\n' 'No key provided.' >&2
  exit 1
fi

bash "${SCRIPT_DIR}/save-key.sh" "$api_key"
