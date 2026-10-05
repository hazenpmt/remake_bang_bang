import assert from "node:assert/strict";
import test from "node:test";

import { createSecurityTelemetry } from "../src/security-telemetry.js";

test("security telemetry redacts credentials and persists bounded batches", async () => {
  const calls = [];
  const telemetry = createSecurityTelemetry({
    nodeId: "test-node",
    hashSecret: "test-security-telemetry-secret-long-enough",
    query: async (sql, parameters) => calls.push({ sql, parameters }),
    batchSize: 2,
  });
  telemetry.record({
    eventType: "auth.login_failed",
    severity: "medium",
    source: "http",
    route: "POST /api/auth/login",
    ip: "127.0.0.1",
    details: {
      username: "tester",
      password: "must-not-persist",
      nested: { session_token: "must-not-persist" },
    },
  });
  await telemetry.flush();
  assert.equal(calls.length, 1);
  const rows = JSON.parse(calls[0].parameters[0]);
  assert.equal(rows[0].details.password, "[redacted]");
  assert.equal(rows[0].details.nested.session_token, "[redacted]");
  assert.match(rows[0].source_ip_hash, /^[a-f0-9]{64}$/);
  assert.equal(rows[0].node_id, "test-node");
  assert.equal(telemetry.health().persisted, 1);
});
