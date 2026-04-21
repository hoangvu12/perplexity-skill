---
name: perplexity-search
description: Search the web with Perplexity Sonar models and return grounded answers with citations. Use for questions that need current information, external sources, or recent updates.
license: MIT
compatibility: "claude-code >= 1.0, opencode >= 0.5"
metadata:
  author: hggaming
  version: "0.1.0"
---

# Perplexity Search

## When to use

Use this skill when the user needs up-to-date information from the web, grounded answers with citations, or a quick research pass over external sources.

Prefer this over local codebase search when the question depends on recent news, API changes, documentation updates, pricing, release notes, or public web content.

## Prerequisites

- `bash`
- `curl`
- `jq`
- A valid Perplexity API key

## Authentication Flow

Run `bash scripts/ask.sh "<question>"` from this skill directory.

The scripts resolve credentials in this order:

1. `PERPLEXITY_API_KEY`
2. `./.env`
3. `~/.config/perplexity/config.json`
4. `~/.perplexity`

If a script exits after printing `PERPLEXITY_AUTH_REQUIRED`, ask the user for their Perplexity API key from `https://perplexity.ai/settings/api`, then run:

```bash
bash scripts/save-key.sh <pplx-key>
```

After saving the key, retry the original command.

## Commands

Default search:

```bash
bash scripts/ask.sh "What changed in Next.js this week?"
```

Pick a model:

```bash
bash scripts/ask.sh "Compare the latest React Compiler guidance" --model sonar-reasoning-pro
```

Add a recency filter:

```bash
bash scripts/ask.sh "What is new in WebGPU?" --recency month
```

Restrict domains:

```bash
bash scripts/ask.sh "What did the CSS Working Group publish?" --domains w3.org,developer.mozilla.org
```

Raw JSON response:

```bash
bash scripts/ask.sh "Summarize the latest Bun release" --json
```

## Flags

- `--model <name>`: defaults to config `default_model` or `sonar-pro`
- `--recency <hour|day|week|month|year>`: optional search recency filter
- `--domains <a,b,-c>`: optional comma-separated domain filter list
- `--search-mode <web|academic|sec>`: optional search mode
- `--reasoning-effort <minimal|low|medium|high>`: reasoning models only
- `--json`: print the raw API response

## Output Rules

- Always return citations to the user when available.
- Prefer concise answers unless the user asks for a long report.
- For code-heavy or multi-step questions, prefer `sonar-reasoning-pro`.
- If Perplexity returns a rate limit error, tell the user and avoid tight retry loops.

## References

- `references/MODELS.md`
- `references/FILTERS.md`
