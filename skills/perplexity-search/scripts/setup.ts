#!/usr/bin/env bun

import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

if (!process.stdin.isTTY) {
  console.error("setup.ts requires an interactive terminal.");
  process.exit(1);
}

const scriptDir = dirname(fileURLToPath(import.meta.url));

function readSecret(promptText: string) {
  return new Promise<string>((resolve) => {
    const stdin = process.stdin;
    const stdout = process.stdout;
    let value = "";

    stdout.write(promptText);
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding("utf8");

    const onData = (chunk: string) => {
      if (chunk === "\u0003") {
        stdin.setRawMode(false);
        stdout.write("\n");
        process.exit(130);
      }

      if (chunk === "\r" || chunk === "\n") {
        stdin.setRawMode(false);
        stdin.pause();
        stdin.off("data", onData);
        stdout.write("\n");
        resolve(value);
        return;
      }

      if (chunk === "\b" || chunk === "\u007f") {
        value = value.slice(0, -1);
        return;
      }

      value += chunk;
    };

    stdin.on("data", onData);
  });
}

console.log("Create a Perplexity API key at https://perplexity.ai/settings/api");
const apiKey = (await readSecret("Perplexity API key: ")).trim();

if (!apiKey) {
  console.error("No key provided.");
  process.exit(1);
}

const result = spawnSync("bun", [join(scriptDir, "save-key.ts"), apiKey], { stdio: "inherit" });
process.exit(result.status || 0);
