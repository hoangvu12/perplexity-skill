# Perplexity Skill

Portable Agent Skill for Perplexity web search via the Sonar models.

## Install

Primary install path:

```bash
npx skills add hggaming/perplexity-skill -g
```

Target a specific agent:

```bash
npx skills add hggaming/perplexity-skill -g -a claude-code
```

Manual fallback:

```bash
git clone https://github.com/hggaming/perplexity-skill
cp -r perplexity-skill/skills/perplexity-search ~/.claude/skills/
```

## Prerequisites

- `bash`
- `curl`
- `jq`
- A Perplexity API key from `https://perplexity.ai/settings/api`

## First Run

The skill checks for a key in this order:

1. `PERPLEXITY_API_KEY`
2. `./.env`
3. `~/.config/perplexity/config.json`
4. `~/.perplexity`

If none is found, the scripts print a `PERPLEXITY_AUTH_REQUIRED` marker. Agents can use that to ask the user for a key, run `scripts/save-key.sh <key>`, then retry the original command.

Manual setup:

```bash
bash skills/perplexity-search/scripts/setup.sh
```

## Included Scripts

- `scripts/ask.sh` - Perplexity chat search wrapper
- `scripts/save-key.sh` - validate and persist API key
- `scripts/setup.sh` - interactive first-run setup for humans
- `scripts/preflight.sh` - shared auth and dependency checks

## Example

```bash
bash skills/perplexity-search/scripts/ask.sh "What changed in WebGPU this month?" --recency month
```

JSON output:

```bash
bash skills/perplexity-search/scripts/ask.sh "Summarize this week in Bun" --json
```
