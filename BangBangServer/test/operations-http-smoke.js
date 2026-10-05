import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = 19_000 + Number.parseInt(randomBytes(2).toString("hex"), 16) % 1_000;
const baseUrl = `http://127.0.0.1:${port}`;
const metricsToken = "operations-smoke-metrics-token-long-enough";
let child = null;
let stderr = "";

async function waitForServer() {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health/ready`);
      if (response.ok) {
        return;
      }
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Operations server did not become ready. ${stderr}`);
}

try {
  child = spawn(process.execPath, ["src/server.js"], {
    cwd: serverRoot,
    env: {
      ...process.env,
      HOST: "127.0.0.1",
      PORT: String(port),
      BATTLE_RUNTIME_ENABLED: "false",
      METRICS_ENABLED: "true",
      METRICS_BEARER_TOKEN: metricsToken,
      RATE_LIMIT_BACKEND: "memory",
      NODE_ENV: "test",
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
  await waitForServer();

  const live = await fetch(`${baseUrl}/health/live`);
  assert.equal(live.status, 200, stderr);
  const ready = await fetch(`${baseUrl}/health/ready`);
  assert.equal(ready.status, 200, stderr);
  const readyPayload = await ready.json();
  assert.equal(readyPayload.rate_limit.ready, true);
  assert.equal(readyPayload.security_telemetry.dropped, 0);

  const unauthorized = await fetch(`${baseUrl}/metrics`);
  assert.equal(unauthorized.status, 401);
  const metrics = await fetch(`${baseUrl}/metrics`, {
    headers: { Authorization: `Bearer ${metricsToken}` },
  });
  assert.equal(metrics.status, 200, stderr);
  const body = await metrics.text();
  assert.match(body, /bangbang_http_requests_total/);
  assert.match(body, /bangbang_process_uptime_seconds/);
  assert.match(body, /bangbang_security_telemetry_dropped_total 0/);
  console.log("OPERATIONS_HTTP_OK");
} finally {
  if (child && child.exitCode == null) {
    child.kill("SIGTERM");
    await new Promise((resolve) => child.once("exit", resolve));
  }
}
