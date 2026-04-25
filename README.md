# Perplexity Skill

Portable Agent Skill for Perplexity web search via the Sonar models.

## Install

Primary install path:

```bash
npx skills add hoangvu12/perplexity-skill -g
```

Target a specific agent:

```bash
npx skills add hoangvu12/perplexity-skill -g -a claude-code
```

Manual fallback:

```bash
git clone https://github.com/hoangvu12/perplexity-skill
cp -r perplexity-skill/skills/perplexity-search ~/.claude/skills/
```

## Prerequisites

- `bun`
- A Perplexity API key from `https://perplexity.ai/settings/api`

## First Run

The skill checks for a key in this order:

1. `PERPLEXITY_API_KEY`
2. `./.env`
3. `~/.config/perplexity/config.json`
4. `~/.perplexity`

If none is found, the scripts print a `PERPLEXITY_AUTH_REQUIRED` marker. Agents can use that to ask the user for a key, run `bun scripts/save-key.ts <key>`, then retry the original command.

Manual setup:

```bash
bun skills/perplexity-search/scripts/setup.ts
```

## Included Scripts

- `scripts/ask.ts` - Perplexity chat search wrapper
- `scripts/save-key.ts` - validate and persist API key
- `scripts/setup.ts` - interactive first-run setup for humans
- `scripts/preflight.ts` - shared auth and config checks

## Example

```bash
bun skills/perplexity-search/scripts/ask.ts "What changed in WebGPU this month?" --recency month
```

JSON output:

```bash
bun skills/perplexity-search/scripts/ask.ts "Summarize this week in Bun" --json
```
