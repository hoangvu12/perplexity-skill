#!/usr/bin/env bun

import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const skillDir = dirname(dirname(fileURLToPath(import.meta.url)));
export const configDir = join(process.env.HOME || process.env.USERPROFILE || "", ".config", "perplexity");
export const configFile = join(configDir, "config.json");
export const legacyKeyFile = join(process.env.HOME || process.env.USERPROFILE || "", ".perplexity");

export type PerplexityConfig = {
  apiKey: string;
  defaultModel?: string;
  defaultRecency?: string;
};

export function emitAuthRequired() {
  console.log("PERPLEXITY_AUTH_REQUIRED");
  console.log("Get a key at https://perplexity.ai/settings/api");
  console.log(`Then run: bun ${join(skillDir, "scripts", "save-key.ts")} <your-key>`);
}

export function isValidKey(value: string | undefined): value is string {
  return /^pplx-[A-Za-z0-9._-]+$/.test(value || "");
}

function stripWrappingQuotes(value: string) {
  return value.replace(/^['"]|['"]$/g, "");
}

function loadDotenv(path: string) {
  if (!existsSync(path)) return {};

  const result: Record<string, string> = {};
  for (const rawLine of readFileSync(path, "utf8").split(/\r?\n/)) {
    const line = rawLine.replace(/^export\s+/, "").trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;

    const separator = line.indexOf("=");
    const key = line.slice(0, separator).trim();
    const value = stripWrappingQuotes(line.slice(separator + 1).trim());
    if (["PERPLEXITY_API_KEY", "PERPLEXITY_DEFAULT_MODEL", "PERPLEXITY_DEFAULT_RECENCY"].includes(key)) {
      result[key] = value;
    }
  }

  return result;
}

function readJsonConfig() {
  if (!existsSync(configFile)) return {};

  try {
    return JSON.parse(readFileSync(configFile, "utf8")) as Record<string, string>;
  } catch {
    return {};
  }
}

function readLegacyKey() {
  if (!existsSync(legacyKeyFile)) return "";
  return readFileSync(legacyKeyFile, "utf8").replace(/[\r\n]/g, "");
}

export function loadConfig(): PerplexityConfig | undefined {
  const dotenv = loadDotenv(join(process.cwd(), ".env"));
  const jsonConfig = readJsonConfig();

  const apiKey = process.env.PERPLEXITY_API_KEY || dotenv.PERPLEXITY_API_KEY || jsonConfig.api_key || readLegacyKey();
  if (!isValidKey(apiKey)) return undefined;

  return {
    apiKey,
    defaultModel: process.env.PERPLEXITY_DEFAULT_MODEL || dotenv.PERPLEXITY_DEFAULT_MODEL || jsonConfig.default_model,
    defaultRecency: process.env.PERPLEXITY_DEFAULT_RECENCY || dotenv.PERPLEXITY_DEFAULT_RECENCY || jsonConfig.default_recency,
  };
}

export function preflight() {
  const config = loadConfig();
  if (!config) {
    emitAuthRequired();
    process.exitCode = 2;
    return undefined;
  }

  return config;
}

export async function perplexityRequest(apiKey: string, payload: unknown) {
  try {
    return await fetch("https://api.perplexity.ai/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch {
    console.error("Perplexity request failed due to a network error.");
    process.exit(1);
  }
}

export async function readErrorMessage(response: Response) {
  try {
    const data = await response.json() as { error?: { message?: string }; message?: string };
    return data.error?.message || data.message || "";
  } catch {
    return "";
  }
}

export function ensureConfigDir() {
  mkdirSync(configDir, { recursive: true });
}

if (import.meta.main) {
  preflight();
}
