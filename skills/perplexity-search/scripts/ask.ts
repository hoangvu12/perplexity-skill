#!/usr/bin/env bun

import { preflight, perplexityRequest, readErrorMessage } from "./preflight";

type AskOptions = {
  query: string;
  model?: string;
  recency?: string;
  domains?: string;
  searchMode?: string;
  reasoningEffort?: string;
  rawJson: boolean;
};

function usage() {
  console.log('Usage: bun scripts/ask.ts "question" [--model sonar-pro] [--recency month] [--domains a,b] [--search-mode web] [--reasoning-effort medium] [--json]');
}

function readArgs(args: string[]): AskOptions | undefined {
  const options: AskOptions = { query: "", rawJson: false };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--model":
        options.model = args[++index] || "";
        break;
      case "--recency":
        options.recency = args[++index] || "";
        break;
      case "--domains":
        options.domains = args[++index] || "";
        break;
      case "--search-mode":
        options.searchMode = args[++index] || "";
        break;
      case "--reasoning-effort":
        options.reasoningEffort = args[++index] || "";
        break;
      case "--json":
        options.rawJson = true;
        break;
      case "-h":
      case "--help":
        usage();
        process.exit(0);
      default:
        if (!options.query) {
          options.query = arg;
        } else {
          console.error(`Unexpected argument: ${arg}`);
          usage();
          process.exit(1);
        }
    }
  }

  if (!options.query) {
    usage();
    process.exitCode = 1;
    return undefined;
  }

  return options;
}

function buildPayload(options: AskOptions, defaultModel?: string, defaultRecency?: string) {
  const payload: Record<string, unknown> = {
    model: options.model || defaultModel || "sonar-pro",
    messages: [
      { role: "system", content: "Be concise. Always cite sources." },
      { role: "user", content: options.query },
    ],
    return_related_questions: true,
  };

  const recency = options.recency || defaultRecency;
  if (recency) payload.search_recency_filter = recency;
  if (options.domains) {
    const values = options.domains.split(",").map((item) => item.trim()).filter(Boolean);
    if (values.length > 0) payload.search_domain_filter = values;
  }
  if (options.searchMode) payload.search_mode = options.searchMode;
  if (options.reasoningEffort) payload.reasoning_effort = options.reasoningEffort;

  return payload;
}

function printAnswer(data: any) {
  const message = data?.choices?.[0]?.message?.content || "";
  console.log(message);

  if (Array.isArray(data?.citations) && data.citations.length > 0) {
    console.log("\nSources:");
    for (const citation of data.citations) console.log(`- ${citation}`);
  }

  if (Array.isArray(data?.related_questions) && data.related_questions.length > 0) {
    console.log("\nRelated:");
    for (const question of data.related_questions) console.log(`- ${question}`);
  }
}

const options = readArgs(Bun.argv.slice(2));
if (!options) process.exit(process.exitCode || 1);

const config = preflight();

if (config) {
  const response = await perplexityRequest(config.apiKey, buildPayload(options, config.defaultModel, config.defaultRecency));

  if (!response.ok) {
    const message = await readErrorMessage(response);
    if (response.status === 401) {
      console.error("Perplexity authentication failed. Re-save the key with bun scripts/save-key.ts <key>.");
    } else if (response.status === 429) {
      console.error("Perplexity rate limit reached. Retry with backoff.");
    } else if (message) {
      console.error(`Perplexity request failed (${response.status}): ${message}`);
    } else {
      console.error(`Perplexity request failed with HTTP ${response.status}.`);
    }
    process.exit(1);
  }

  const data = await response.json();
  if (options.rawJson) {
    console.log(JSON.stringify(data, null, 2));
  } else {
    printAnswer(data);
  }
}
