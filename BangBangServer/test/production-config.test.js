import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseEnvironment = {
  ...process.env,
  NODE_ENV: "production",
  REGISTRATION_HASH_SECRET: "registration-secret-that-is-long-enough",
  RATE_LIMIT_KEY_SECRET: "rate-limit-secret-that-is-long-enough",
  METRICS_ENABLED: "true",
  METRICS_BEARER_TOKEN: "metrics-token-that-is-long-enough-123",
  ALLOWED_ORIGIN: "https://game.example",
  WEB_PROXY_SECRET: "proxy-secret-that-is-long-enough-1234",
  BATTLE_PUBLIC_REALTIME_URL: "wss://battle.example/api/realtime/battle",
  CONTENT_PUBLIC_BASE_URL: "https://content.example",
};

function loadConfig(environment) {
  return spawnSync(
    process.execPath,
    ["--input-type=module", "--eval", "await import('./src/config.js')"],
    { cwd: serverRoot, env: environment, encoding: "utf8", windowsHide: true },
  );
}

test("production refuses process-local rate limiting", () => {
  const result = loadConfig({
    ...baseEnvironment,
    RATE_LIMIT_BACKEND: "memory",
    REDIS_URL: "",
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Production requires RATE_LIMIT_BACKEND=redis/);
});

test("production accepts protected metrics, signed proxy and secure realtime route", () => {
  const result = loadConfig({
    ...baseEnvironment,
    RATE_LIMIT_BACKEND: "redis",
    REDIS_URL: "rediss://redis.example:6379",
  });
  assert.equal(result.status, 0, result.stderr);
});

test("production refuses content delivery without HTTPS", () => {
  const result = loadConfig({
    ...baseEnvironment,
    RATE_LIMIT_BACKEND: "redis",
    REDIS_URL: "rediss://redis.example:6379",
    CONTENT_PUBLIC_BASE_URL: "http://content.example",
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /https:\/\/ CONTENT_PUBLIC_BASE_URL/);
});
