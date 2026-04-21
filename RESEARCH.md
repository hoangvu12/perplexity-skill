# Perplexity Skill — Research Notes

Research dump for designing a portable Agent Skill that calls the Perplexity API from Claude Code, opencode, and any other Agent-Skills-compatible editor. Gathered April 2026.

---

## Table of Contents

1. [Agent Skills — the open standard (agentskills.io)](#1-agent-skills--the-open-standard-agentskillsio)
2. [skills.sh — the install package](#2-skillssh--the-install-package)
3. [SKILL.md spec (frontmatter + body)](#3-skillmd-spec-frontmatter--body)
4. [Where skills live on disk (portability matrix)](#4-where-skills-live-on-disk-portability-matrix)
5. [Bundling helper scripts](#5-bundling-helper-scripts)
6. [Perplexity API — complete reference](#6-perplexity-api--complete-reference)
7. [Authentication design for the skill](#7-authentication-design-for-the-skill)
8. [Proposed skill layout + distribution plan](#8-proposed-skill-layout--distribution-plan)
9. [Open questions / decisions to make](#9-open-questions--decisions-to-make)
10. [Sources](#10-sources)

> **Two things named "skills" — don't confuse them:**
> - **agentskills.io** — the open *format spec* for `SKILL.md` (originated by Anthropic, now community-governed).
> - **skills.sh** — a standalone npm package (`vercel-labs/skills`, ran via `npx skills`) that installs SKILL.md packages from GitHub repos into the right directory for whichever agent(s) you have. Built by people at Vercel but it's just a package, not part of Vercel's product/CLI. Same file format as agentskills.io, different layer.

---

## 1. Agent Skills — the open standard (agentskills.io)

**Agent Skills** are folders containing instructions, scripts, and resources that agents discover and load on demand. Format originated at Anthropic (Oct 2025), released as an open standard (Dec 2025), spec lives at **agentskills.io**, reference skills at **github.com/anthropics/skills**. This is the *format* layer.

### Official adopters (as of April 2026)

Confirmed from the agentskills.io homepage carousel:

| Agent / tool | Skills docs |
|---|---|
| Claude Code | https://code.claude.com/docs/en/skills |
| Claude (claude.ai) | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview |
| OpenCode | https://opencode.ai/docs/skills/ |
| OpenAI Codex | https://developers.openai.com/codex/skills/ |
| GitHub Copilot | https://docs.github.com/en/copilot/concepts/agents/about-agent-skills |
| VS Code | https://code.visualstudio.com/docs/copilot/customization/agent-skills |
| Cursor | https://cursor.com/docs/context/skills |
| Gemini CLI | https://geminicli.com/docs/cli/skills/ |
| JetBrains Junie | https://junie.jetbrains.com/docs/agent-skills.html |
| OpenHands | https://docs.openhands.dev/overview/skills |
| Amp | https://ampcode.com/manual#agent-skills |
| Goose (Block) | https://block.github.io/goose/docs/guides/context-engineering/using-skills/ |
| Roo Code | https://docs.roocode.com/features/skills |
| Kiro | https://kiro.dev/docs/skills/ |
| Mistral Vibe | https://github.com/mistralai/mistral-vibe |
| Laravel Boost | https://laravel.com/docs/12.x/boost#agent-skills |
| Databricks Genie Code | https://docs.databricks.com/aws/en/assistant/skills |
| Snowflake Cortex Code | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility#extensibility-skills |
| Letta, Firebender, Mux, Ona, Piebald, Factory, TRAE, Spring AI, Autohand, pi, Workshop, Emdash, nanobot, fast-agent, Command Code, Qodo, VT Code, Google AI Edge Gallery, Agentman | (see agentskills.io) |

**Takeaway:** if the skill conforms to the open spec, the same folder drops into ~all major agents with zero changes — and **skills.sh's CLI handles the per-agent install paths for us** (see §2).

### Why the standard exists

- **For skill authors:** build once, deploy across many agent products.
- **For compatible agents:** users get new capabilities out of the box.
- **For teams/enterprises:** capture org knowledge in portable, version-controlled packages.

---

## 2. skills.sh — the install package

**skills.sh** is a standalone npm package, separate from the format spec. Repo: `vercel-labs/skills` (made by people at Vercel — but it's just a package, *not* part of Vercel's product or CLI). Launched 2026-01-20. It's the *distribution* layer.

- **Site:** https://skills.sh — directory + leaderboard for community skills
- **Repo:** https://github.com/vercel-labs/skills
- **Tagline:** *"The Open Agent Skills Ecosystem"*
- **Install command (no install needed):** `npx skills add <owner/repo>`
- **Supports 45+ agents** including Claude Code, OpenCode, Codex, Cursor, Cline, Windsurf, Amp, Goose, Kiro, Roo, Trae, Antigravity, Gemini CLI, GitHub Copilot, Droid, Kilo, Clawdbot.
- **No registry submission flow** — telemetry from `npx skills add` automatically populates skills.sh.
- Within 6 hours of launch the top skill had >20k installs; `find-skills` alone has 235k+ weekly installs.

### CLI subcommands

| Command | Purpose |
|---|---|
| `npx skills add <owner/repo>` | Install skill(s) from a GitHub repo |
| `npx skills find <query>` | Search the registry interactively |
| `npx skills list` / `ls` | List installed skills |
| `npx skills init` | Scaffold a new SKILL.md template |
| `npx skills update` | Update installed skills |
| `npx skills remove` / `rm` | Uninstall |

Common flags: `-g` global, `-a <agent>` target one agent, `-s <skill>` pick one skill from a multi-skill repo, `--all` install everything, `-y` non-interactive (CI-friendly), `--copy` copy instead of symlink.

### Examples

```bash
# Install a single skill globally for Claude Code
npx skills add hggaming/perplexity-skill -g -a claude-code

# Install everything to all detected agents
npx skills add hggaming/perplexity-skill --all

# Install one skill from a multi-skill repo
npx skills add vercel-labs/agent-skills --skill frontend-design

# CI-safe non-interactive install
npx skills add hggaming/perplexity-skill --skill perplexity-search -g -a claude-code -y
```

### Where skills.sh installs (per agent)

Project scope (default):
- Claude Code → `.claude/skills/`
- Cursor → `.agents/skills/`
- OpenCode → `.agents/skills/`
- Generic fallback → `.agents/skills/`

Global scope (`-g`):
- Claude Code → `~/.claude/skills/`
- Cursor → `~/.cursor/skills/`
- OpenCode → `~/.config/opencode/skills/`
- Windsurf → `~/.codeium/windsurf/skills/`
- (45+ agent paths total, all handled by the CLI)

By default skills.sh **symlinks** a single source into each agent dir, so updates propagate. `--copy` makes independent copies.

### Where it discovers skills inside a repo

When installing from `owner/repo`, skills.sh looks for SKILL.md at:
- Root `SKILL.md`
- `skills/`
- `skills/.curated/`, `skills/.experimental/`, `skills/.system/`
- `.claude/skills/`, `.agents/skills/`

So **how we structure the repo determines whether `npx skills add` works**:

```
perplexity-skill/                ← repo root
└── skills/
    └── perplexity-search/
        ├── SKILL.md
        └── scripts/
            ├── ask.sh
            └── preflight.sh
```

With this layout, `npx skills add hggaming/perplexity-skill` would auto-detect `perplexity-search` and offer to install it.

### Optional metadata

`metadata.internal: true` in frontmatter hides a skill from public discovery unless the user sets `INSTALL_INTERNAL_SKILLS=1`. Useful if we want a private utility skill in the same repo.

### Why this matters for us

- **Distribution problem solved.** Users on Claude Code, opencode, Cursor, Codex, Windsurf, etc. all run the same `npx skills add hggaming/perplexity-skill` and skills.sh puts files in the right per-agent path.
- **No need for shell install scripts** in our README — `npx skills` is the install story.
- **Versioning** is just `git tag` on our repo.
- **Update flow** is `npx skills update`.

---

## 3. SKILL.md spec (frontmatter + body)

Each skill is a **folder** containing (at minimum) a `SKILL.md` file with YAML frontmatter plus instructional markdown.

### Required frontmatter

```yaml
---
name: perplexity-search            # REQUIRED
description: Search the web with   # REQUIRED
  Perplexity's Sonar models and
  return grounded answers with
  citations. Use for questions
  needing up-to-date info.
---
```

### Validation rules (from opencode / the shared spec)

| Field | Rule |
|---|---|
| `name` | 1–64 chars, lowercase alphanumeric + hyphens, no leading/trailing `-`, no `--`, must match directory name. Regex: `^[a-z0-9]+(-[a-z0-9]+)*$` |
| `description` | 1–1024 chars. Should explain **what** the skill does AND **when** to use it (agents match on this). |

### Optional frontmatter (per opencode spec)

```yaml
license: MIT
compatibility: "claude-code >= 1.0, opencode >= 0.5"
metadata:
  author: your-name
  version: "0.1.0"
```

> "Unknown frontmatter fields are ignored." — opencode docs. Good: we can stick extra fields without breaking other clients.

### Body = instructions

The markdown body is the prompt the agent receives when the skill is activated. Pattern:

```markdown
# Perplexity Search

## When to use
Use this skill when...

## How to use
1. Ensure PERPLEXITY_API_KEY is available (see scripts/preflight.sh).
2. Call `scripts/ask.sh "<question>" [--model sonar-pro] [--recency week]`
3. The script prints the answer followed by a "Sources:" section.

## Models
- `sonar`         — quick lookups ($1 in / $1 out per 1M tokens)
- `sonar-pro`     — default, harder queries, 200k context
- `sonar-reasoning-pro` — step-by-step reasoning, exposes `<think>`
- `sonar-deep-research` — multi-search exhaustive report

## Examples
...

## Guidelines / limits
- Rate limit (tier 0): 50 req/min for sonar-pro, 5 req/min for deep-research.
- Always surface citations back to the user.
- For code-focused queries prefer sonar-reasoning-pro.
```

### Progressive disclosure

Agents don't load all skill bodies into the prompt. The built-in `skill` tool lists **name + description only**; the agent decides to load the full `SKILL.md` (and any referenced files) when the task matches. Keep `description` precise — that's the only signal for matching.

---

## 4. Where skills live on disk (portability matrix)

> Reminder: if you install via `npx skills add` (§2), the CLI handles all of these paths automatically. This section is for understanding what gets written, and for users who want to install manually.

Both project-local and user-global locations exist. Clients **search multiple of these** so one skill file can be visible to all of them.

### Project-level (committed to repo)

| Path | Used by |
|---|---|
| `.claude/skills/<name>/SKILL.md` | Claude Code, opencode, most others |
| `.opencode/skills/<name>/SKILL.md` | opencode (canonical) |
| `.agents/skills/<name>/SKILL.md` | opencode and several others as generic fallback |

### User-global

| Path | Used by |
|---|---|
| `~/.claude/skills/<name>/SKILL.md` | Claude Code, opencode |
| `~/.config/opencode/skills/<name>/SKILL.md` | opencode |
| `~/.agents/skills/<name>/SKILL.md` | opencode + others |

### Recommendation for this skill

Ship it at `perplexity-search/` as a standalone folder, then tell users to either:
- Symlink / copy into `~/.claude/skills/perplexity-search/` (works for Claude Code + opencode), or
- Drop into a project's `.claude/skills/perplexity-search/` for team use.

Because `.claude/skills/` is recognized by nearly every adopter (opencode, Claude Code, and others explicitly list it as a read path), that's the lowest-common-denominator install target.

---

## 5. Bundling helper scripts

(Note: this is **not** related to the `skills.sh` CLI in §2 — that's just the project name. Here we're talking about shipping `.sh` helper files inside the skill folder.)

The skill folder can contain more than `SKILL.md`. Typical convention seen in `anthropics/skills`:

```
my-skill/
├── SKILL.md              # required, entrypoint
├── scripts/              # executable helpers
│   ├── ask.sh
│   └── preflight.sh
├── references/           # extra docs the agent loads on demand
│   └── MODELS.md
└── assets/               # templates, schemas, sample data
    └── response.schema.json
```

### Why shell scripts over "call the API from the prompt"

- **Portable across runtimes.** Every supported agent has shell execution; far fewer have a built-in HTTP client.
- **Deterministic.** The LLM doesn't have to reconstruct curl flags or JSON each call; it just runs `scripts/ask.sh "question"`.
- **Auditable.** Scripts are reviewable, version-controllable, and can be run by humans too.
- **Progressive disclosure works.** The agent reads SKILL.md (small), doesn't load the script contents unless something fails.

### How scripts are invoked

From SKILL.md the agent is told, e.g.:

```markdown
Run `bash scripts/ask.sh "$QUERY"` from the skill directory.
```

Agents resolve paths relative to the skill folder. Some clients expose a variable like `$SKILL_DIR` / `$CLAUDE_SKILL_DIR`, but the safe portable pattern is to have the script `cd` into its own directory:

```bash
#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

### Windows note (this machine)

The user's platform is Windows 11 with bash available. Make scripts POSIX-sh-compatible, use `#!/usr/bin/env bash`, forward-slash paths, and `jq` for JSON. Document `jq` as a prerequisite (or ship a tiny Python fallback).

---

## 6. Perplexity API — complete reference

All data below pulled from `docs.perplexity.ai` (April 2026).

### Base URL and auth

- Base: `https://api.perplexity.ai`
- Auth header: `Authorization: Bearer $PERPLEXITY_API_KEY`
- Key format: `pplx-<hex>` (e.g. `pplx-1234567890abcdef`)
- Keys are generated at `https://api.perplexity.ai/settings/api` (requires billing group with payment method). **Keys are shown once** — save immediately.
- Revoked key → 401 `AuthenticationError`.

### Endpoints relevant to this skill

| Purpose | Method + path | Notes |
|---|---|---|
| Chat with web search | `POST /chat/completions` | OpenAI-compatible, most ecosystems use this |
| Chat (newer canonical) | `POST /v1/sonar` | Same shape, recent docs prefer this |
| Async deep research | `POST /v1/async/sonar` → `GET /v1/async/sonar/{id}` | For sonar-deep-research, returns request_id for polling |
| Raw ranked search | `POST /search` | No LLM generation, flat $5 / 1k req |
| Embeddings | `POST /v1/embeddings` | For RAG use cases |
| Agent (multi-model) | `POST /v1/agent` | Access GPT/Claude/Gemini/Grok through Perplexity |

### Models (Sonar family)

| Model | Context | Input $/1M | Output $/1M | Best for |
|---|---|---|---|---|
| `sonar` | 127k | $1 | $1 | Quick factual lookups |
| `sonar-pro` | 200k | $3 | $15 | Default, complex queries, multi-turn |
| `sonar-reasoning-pro` | 128k | $2 | $8 + $3/1M reasoning | Multi-step logic, visible `<think>` block |
| `sonar-deep-research` | 128k | $2 | $8 + $3/1M reasoning + $2/1M citations + $5/1k searches | Exhaustive multi-source reports |

Additional per-request search fees apply ($5–$14 depending on search context size).

### Request body (chat completions)

```json
{
  "model": "sonar-pro",
  "messages": [
    { "role": "system", "content": "Be concise. Always cite sources." },
    { "role": "user",   "content": "What's new in WebGPU this month?" }
  ],
  "max_tokens": 1000,
  "temperature": 0.2,
  "top_p": 0.9,
  "stream": false,
  "return_images": false,
  "return_related_questions": true,
  "search_recency_filter": "month",
  "search_domain_filter": ["w3.org", "developer.mozilla.org", "-reddit.com"],
  "search_mode": "web",
  "reasoning_effort": "medium",
  "response_format": {
    "type": "json_schema",
    "json_schema": { "name": "answer", "schema": { "...": "..." } }
  }
}
```

Full parameter list:

| Param | Type | Notes |
|---|---|---|
| `model` | string | Required |
| `messages` | array | Required, OpenAI-shape (role/content) |
| `max_tokens` | int 0–128000 | |
| `temperature` | 0–2 | |
| `top_p` | 0–1 | |
| `top_k` | int | |
| `stream` | bool | SSE events if true |
| `stop` | string \| array | |
| `presence_penalty` / `frequency_penalty` | number | |
| `response_format` | object | JSON-schema structured output |
| `search_mode` | `web` \| `academic` \| `sec` | |
| `return_images` | bool | |
| `return_related_questions` | bool | |
| `disable_search` | bool | Pure LLM mode |
| `search_domain_filter` | array | Up to 20. Prefix `-` to deny. Can't mix allow+deny in one call. |
| `search_recency_filter` | `hour`\|`day`\|`week`\|`month`\|`year` | |
| `search_after_date_filter` / `search_before_date_filter` | `MM/DD/YYYY` | |
| `last_updated_after_filter` / `last_updated_before_filter` | `MM/DD/YYYY` | |
| `search_language_filter` | array of ISO 639-1 | Up to 20 |
| `web_search_options` | object | Fine control of retrieval |
| `reasoning_effort` | `minimal`\|`low`\|`medium`\|`high` | Reasoning models only |

### Response shape

```json
{
  "id": "a1b2c3d4-...",
  "model": "sonar-pro",
  "created": 1745000000,
  "choices": [{
    "index": 0,
    "finish_reason": "stop",
    "message": { "role": "assistant", "content": "…answer…" }
  }],
  "citations": ["https://example.com/a", "https://example.com/b"],
  "search_results": [
    {
      "title": "…",
      "url":   "https://example.com/a",
      "snippet": "…",
      "date": "2026-04-15",
      "last_updated": "2026-04-20"
    }
  ],
  "images": [ { "image_url": "...", "origin_url": "...", "width": 800, "height": 600 } ],
  "usage": { "prompt_tokens": 14, "completion_tokens": 287, "total_tokens": 301 }
}
```

### Minimal curl (what the skills.sh will wrap)

```bash
curl -sS -X POST "https://api.perplexity.ai/chat/completions" \
  -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sonar-pro",
    "messages": [{"role":"user","content":"What is new in WebGPU this month?"}],
    "search_recency_filter": "month",
    "return_related_questions": true
  }' | jq .
```

### SDKs (not strictly needed — we'll use curl from bash)

- Python: `pip install perplexityai` → `from perplexity import Perplexity`
- TypeScript: `@perplexity-ai/perplexity_ai`
- **OpenAI-SDK compatible**: point base_url to `https://api.perplexity.ai/v1`, keep `OpenAI` client.

### Rate limits (tier 0, free / new key)

- sonar-pro / sonar-reasoning-pro: 50 req/min
- sonar-deep-research: 5 req/min
- Search API: 50 req/s (independent)
- Tier climbs automatically with cumulative spend ($50 → tier 1, $250 → tier 2, etc.)
- 429 → exponential backoff.

### Error taxonomy

| HTTP | SDK exception | Cause |
|---|---|---|
| 401 | `AuthenticationError` | Bad/revoked key or no credits |
| 429 | `RateLimitError` | Tier exceeded; retry with backoff |
| 4xx/5xx | `APIStatusError` | Check `status_code`, `message`, `X-Request-ID` header |
| network | `APIConnectionError` | Transient; retry |
| schema | `ValidationError` | Local parameter problem |

---

## 7. Authentication design for the skill

Perplexity only supports **API keys** — no OAuth, no device flow. This is actually good for a portable skill because all we need is to reliably locate one secret string across machines and editors.

### Resolution order (recommended)

The skill's `preflight.sh` should check, in this order:

1. **`$PERPLEXITY_API_KEY` env var** — standard, matches what the official Perplexity SDKs read automatically. Works out of the box in any agent.
2. **Local `.env` file** in the current working directory — `source`-able, common for per-project keys.
3. **User config file at `~/.config/perplexity/config.json`** — portable across Linux/macOS/Windows (git-bash). Shape:
   ```json
   { "api_key": "pplx-...", "default_model": "sonar-pro" }
   ```
4. **`~/.perplexity` fallback** (legacy plaintext) — single-line file, easy for users to drop in.
5. **Fail clearly** with a message: "No PERPLEXITY_API_KEY found. Get one at https://perplexity.ai/settings/api and export it or save to ~/.config/perplexity/config.json."

### Why not prompt the user interactively

Agents run non-interactively most of the time. A TTY-gated prompt would hang in Claude Code / opencode background sessions. Better to fail fast with a clear remediation string — the host agent can then ask the user.

### What NOT to do

- **Never** write the key into `SKILL.md` or any file inside the skill folder (it will get committed).
- **Don't** hardcode a fallback key.
- **Don't** pass the key as a CLI flag in a way that leaks into process lists or shell history; prefer env-var export inside the script.

### Cross-platform storage note

- macOS: users might want to store key in Keychain; document but don't require.
- Linux: same, consider `secret-tool`.
- Windows: users often just `setx PERPLEXITY_API_KEY pplx-...`. The env-var path already handles this.

Keeping the skill to env-var + config-file resolution avoids platform secret-store coupling and keeps it portable.

### First-run auth flow (no manual `export` required)

The cleanest UX — works identically across Claude Code, opencode, Cursor, Codex, etc. — is to **let the skill instruct the agent to ask the user in chat, then persist the key once**. No TTY prompts, no install hooks, no agent-specific APIs.

**Flow:**

1. Agent runs `scripts/ask.sh "question"`.
2. `ask.sh` sources `preflight.sh`, which checks in order: `$PERPLEXITY_API_KEY` → `.env` → `~/.config/perplexity/config.json`.
3. None found → `preflight.sh` exits with code `2` and prints a **structured marker** the agent can parse:
   ```
   PERPLEXITY_AUTH_REQUIRED
   Get a key at https://perplexity.ai/settings/api
   Then run: scripts/save-key.sh <your-key>
   ```
4. `SKILL.md` includes an explicit handling section the agent follows:
   > If a script exits with `PERPLEXITY_AUTH_REQUIRED`, ask the user for their Perplexity API key (link them to https://perplexity.ai/settings/api), then run `scripts/save-key.sh <key>`, then retry the original command.
5. The agent asks the user in chat: *"I need a Perplexity API key. Grab one at [link]. Paste it here."*
6. User pastes `pplx-...`.
7. Agent runs `scripts/save-key.sh pplx-...` → validates format, makes a probe call, writes `~/.config/perplexity/config.json` with `chmod 600`.
8. Agent retries `ask.sh` → works.
9. **Every subsequent run:** silent — key comes from the config file.

**Why this works across every editor:**

- Every skills-compatible agent can (a) ask the user in chat and (b) run shell commands — that's the interaction model. We don't need any agent-specific prompt API.
- No TTY-gated `read` calls (those hang in background/non-interactive agent sessions).
- No install-time prompt (skills.sh doesn't run post-install hooks).
- The key lives outside the skill folder (`~/.config/perplexity/`), so reinstalling or updating the skill via `npx skills update` doesn't lose it.

**Three scripts, clearly separated roles:**

| Script | Job | Interactive? |
|---|---|---|
| `preflight.sh` | Silently check env → `.env` → config file. Exit 0 if found, exit 2 + `PERPLEXITY_AUTH_REQUIRED` marker if not. | **Never** prompts. |
| `save-key.sh <key>` | Validate format (`^pplx-`), make a probe GET/POST to confirm the key works, then write `~/.config/perplexity/config.json` mode 0600. Clear error on 401. | No. |
| `ask.sh` | Source preflight; on exit 2 re-emit marker so the agent can act; on success build the request body and curl Perplexity. | No. |

**Optional:** ship `scripts/setup.sh` for humans who prefer a manual `bash setup.sh` — uses `read -s` to prompt interactively. Useful outside an agent session (terminal setup, CI bootstrap). Not on the agent's hot path.

**Config file shape:**

```json
{
  "api_key": "pplx-...",
  "default_model": "sonar-pro",
  "default_recency": "month"
}
```

JSON (not dotenv) because future settings — default model, default recency filter, allowed domains — can live there too, and we're already depending on `jq` for request-body construction.

**Cross-platform path:** `$HOME/.config/perplexity/config.json`. Works on macOS, Linux, and Windows git-bash (resolves `$HOME` to `%USERPROFILE%`). Native Windows CMD users would need a separate fallback — probably not worth MVP unless requested.

**Security:**
- `chmod 600` the config file on write.
- Skill must not echo the key back to the user or include it in logs/prints.
- `.gitignore` `.env` in the skill template (in case a user drops one in a project and later commits).

---

## 8. Proposed skill layout + distribution plan

Draft — not yet created, user said "no code yet". Layout chosen so `npx skills add` (the skills.sh package) auto-discovers it:

```
perplexity-skill/                ← repo root (what users `npx skills add`)
├── README.md                    # human-facing install + use
└── skills/
    └── perplexity-search/       ← skills.sh looks here
        ├── SKILL.md             # frontmatter + usage docs
        ├── scripts/
        │   ├── preflight.sh     # silent key-resolver: env → .env → config; exits 2 w/ marker if missing
        │   ├── save-key.sh      # validate + probe + persist key to ~/.config/perplexity/config.json (0600)
        │   ├── setup.sh         # OPTIONAL human-facing interactive `read -s` prompt
        │   ├── ask.sh           # thin wrapper: ask.sh "Q" [--model X] [--recency Y]
        │   ├── deep-research.sh # async flow: POST then poll /v1/async/sonar/{id}
        │   └── search.sh        # /search endpoint, raw ranked results
        └── references/
            ├── MODELS.md        # pricing/context-window cheatsheet
            └── FILTERS.md       # domain + recency filter syntax
```

### What `ask.sh` does (in prose)

1. Source `preflight.sh` → exports `PERPLEXITY_API_KEY` or exits with instructions.
2. Parse flags: `--model`, `--recency`, `--domains`, `--json`.
3. Build JSON body with `jq -n --arg q "$1" ... '{model:$model, messages:[{role:"user",content:$q}], ...}'` to avoid quoting bugs.
4. POST to `https://api.perplexity.ai/chat/completions` with curl.
5. On 200: extract `.choices[0].message.content` and a formatted `.citations[]` list. If `--json` flag, dump raw response.
6. On 401/429: print remediation and exit non-zero so the agent knows.

### Install instructions

**Primary path (via the skills.sh package — works for 45+ agents):**

```bash
# Auto-detect installed agents, install globally
npx skills add hggaming/perplexity-skill -g

# Or target specific agents
npx skills add hggaming/perplexity-skill -g -a claude-code -a opencode -a cursor
```

**That's it — no API key setup step.** The first time the user asks the skill to do something, the agent will prompt them in chat for the key, save it to `~/.config/perplexity/config.json`, and never ask again. Users who prefer the env-var approach can still `export PERPLEXITY_API_KEY=pplx-...` and it'll be picked up first.

**Manual fallback (if the user doesn't want npx):**

```bash
git clone https://github.com/hggaming/perplexity-skill
cp -r perplexity-skill/skills/perplexity-search ~/.claude/skills/
```

---

## 9. Open questions / decisions to make

Before writing code, confirm with the user:

1. **Python or bash?** Bash+curl+jq is most portable but requires `jq`. Python requires 3.9+ but handles JSON natively and supports streaming cleanly. Possible answer: **bash default, Python fallback** (ship both, pick at runtime). Note the user specifically said "using skills.sh is a must" — that refers to distributing via the skills.sh npm package (§2), which is agnostic to our internal script language, so this choice is independent.
2. **Streaming support?** SSE in bash is ugly. Start without streaming — add later if needed.
3. **Deep research model?** It's async and can take minutes — do we want this in the MVP or keep it to the synchronous `sonar-pro`?
4. **Config file format?** JSON (needs jq) vs. INI/dotenv (plain bash). Leaning JSON at `~/.config/perplexity/config.json` because it matches modern conventions.
5. **Skill name.** `perplexity-search` or just `perplexity`? Current spec allows either. `perplexity-search` is more descriptive → better progressive-disclosure matching.
6. **Structured output.** Expose `response_format` JSON-schema passthrough? Useful for downstream parsing but adds complexity.
7. **MCP vs Skill.** There's already a Perplexity MCP server (used in this conversation). Confirm the user wants a skill (lower friction, ships as files) rather than an MCP server (more capable, needs a runtime process).

---

## 10. Sources

### Agent Skills (format spec)
- https://agentskills.io/home — landing page + full adopter list
- https://agentskills.io/specification — formal spec
- https://github.com/anthropics/skills — reference skills, SKILL.md template
- https://opencode.ai/docs/skills/ — opencode skill rules (validation regex, dir layout, permissions)
- https://code.claude.com/docs/en/skills — Claude Code skill docs

### skills.sh (standalone npm package, by Vercel team)
- https://skills.sh — directory + leaderboard
- https://github.com/vercel-labs/skills — CLI source (`npx skills`)
- https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem — launch post (2026-01-20)
- https://vercel.com/docs/agent-resources/skills — Vercel's docs for the ecosystem
- https://vercel.com/kb/guide/agent-skills-creating-installing-and-sharing-reusable-agent-context — authoring guide
- https://www.infoq.com/news/2026/02/vercel-agent-skills/ — InfoQ coverage

### Perplexity API
- https://docs.perplexity.ai/docs/getting-started/overview
- https://docs.perplexity.ai/docs/getting-started/quickstart
- https://docs.perplexity.ai/docs/getting-started/pricing
- https://docs.perplexity.ai/docs/sonar/models
- https://docs.perplexity.ai/docs/sonar/quickstart
- https://docs.perplexity.ai/api-reference/sonar-post
- https://docs.perplexity.ai/api-reference/chat-completions-post
- https://docs.perplexity.ai/api-reference/generate-auth-token-post
- https://docs.perplexity.ai/api-reference/async-sonar-post
- https://docs.perplexity.ai/api-reference/search-post
- https://docs.perplexity.ai/docs/agent-api/models
- https://docs.perplexity.ai/docs/agent-api/filters
- https://docs.perplexity.ai/docs/search/filters/domain-filter
- https://docs.perplexity.ai/docs/admin/rate-limits-usage-tiers
- https://docs.perplexity.ai/docs/sdk/overview
- https://docs.perplexity.ai/docs/sdk/error-handling
- https://docs.perplexity.ai/docs/agent-api/openai-compatibility
- https://docs.perplexity.ai/docs/resources/feature-roadmap
- https://docs.perplexity.ai/llms-full.txt — full docs as single file (useful for caching)

### API key setup
- https://api.perplexity.ai/settings/api — portal to create/revoke keys
