#!/usr/bin/env bun

import { chmodSync, writeFileSync } from "node:fs";
import { configFile, ensureConfigDir, isValidKey, perplexityRequest, readErrorMessage } from "./preflight";

type SaveKeyOptions = {
  apiKey: string;
  defaultModel: string;
  defaultRecency?: string;
};

function usage() {
  console.log("Usage: bun scripts/save-key.ts <pplx-key> [--model sonar-pro] [--recency month]");
}

function readArgs(args: string[]): SaveKeyOptions | undefined {
  const options: SaveKeyOptions = { apiKey: "", defaultModel: "sonar-pro" };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    switch (arg) {
      case "--model":
        options.defaultModel = args[++index] || "";
        break;
      case "--recency":
        options.defaultRecency = args[++index] || "";
        break;
      case "-h":
      case "--help":
        usage();
        process.exit(0);
      default:
        if (!options.apiKey) {
          options.apiKey = arg;
        } else {
          console.error(`Unexpected argument: ${arg}`);
          usage();
          process.exit(1);
        }
    }
  }

  if (!options.apiKey) {
    usage();
    process.exitCode = 1;
    return undefined;
  }

  if (!isValidKey(options.apiKey)) {
    console.error("Invalid key format. Expected a value starting with pplx-.");
    process.exitCode = 1;
    return undefined;
  }

  return options;
}

const options = readArgs(Bun.argv.slice(2));

if (options) {
  const probeBody = {
    model: "sonar",
    messages: [{ role: "user", content: "Reply with the single word ok." }],
    max_tokens: 16,
    disable_search: true,
  };

  const response = await perplexityRequest(options.apiKey, probeBody);
  if (!response.ok) {
    if (response.status === 401) {
      console.error("Perplexity rejected the key with 401 Unauthorized.");
    } else {
      const message = await readErrorMessage(response);
      if (message) {
        console.error(`Perplexity probe failed (${response.status}): ${message}`);
      } else {
        console.error(`Perplexity probe failed with HTTP ${response.status}.`);
      }
    }
    process.exit(1);
  }

  ensureConfigDir();
  const config: Record<string, string> = {
    api_key: options.apiKey,
    default_model: options.defaultModel,
  };
  if (options.defaultRecency) config.default_recency = options.defaultRecency;

  writeFileSync(configFile, `${JSON.stringify(config, null, 2)}\n`, "utf8");
  try {
    chmodSync(configFile, 0o600);
  } catch {
    // Windows may not support POSIX permissions here.
  }

  console.log(`Saved Perplexity config to ${configFile}`);
}
