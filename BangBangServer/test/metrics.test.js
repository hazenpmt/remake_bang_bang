import assert from "node:assert/strict";
import test from "node:test";

import { createHttpMetrics } from "../src/metrics.js";

test("HTTP metrics stay bounded to supplied route labels and render Prometheus text", () => {
  const metrics = createHttpMetrics();
  metrics.record("GET", "/health/ready", 200, 0.125);
  metrics.record("GET", "/health/ready", 503, 0.25);
  const output = metrics.render({ realtime_connections: 3 });
  assert.match(output, /bangbang_http_requests_total\{method="GET",route="\/health\/ready",status="200"\} 1/);
  assert.match(output, /bangbang_http_request_duration_seconds_count\{method="GET",route="\/health\/ready"\} 2/);
  assert.match(output, /bangbang_realtime_connections 3/);
});
