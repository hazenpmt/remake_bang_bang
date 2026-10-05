function escapeLabel(value) {
  return String(value).replaceAll("\\", "\\\\").replaceAll("\n", "\\n").replaceAll('"', '\\"');
}

export function createHttpMetrics() {
  const requests = new Map();
  const durations = new Map();

  function record(method, route, status, durationSeconds) {
    const labels = `${method}\u0000${route}\u0000${status}`;
    requests.set(labels, (requests.get(labels) ?? 0) + 1);
    const durationKey = `${method}\u0000${route}`;
    const current = durations.get(durationKey) ?? { count: 0, sum: 0 };
    current.count += 1;
    current.sum += Math.max(0, Number(durationSeconds) || 0);
    durations.set(durationKey, current);
  }

  function render(gauges = {}) {
    const lines = [
      "# HELP bangbang_http_requests_total Total HTTP responses.",
      "# TYPE bangbang_http_requests_total counter",
    ];
    for (const [key, count] of [...requests.entries()].sort()) {
      const [method, route, status] = key.split("\u0000");
      lines.push(
        `bangbang_http_requests_total{method="${escapeLabel(method)}",route="${escapeLabel(route)}",status="${escapeLabel(status)}"} ${count}`,
      );
    }
    lines.push(
      "# HELP bangbang_http_request_duration_seconds_sum Total HTTP response time.",
      "# TYPE bangbang_http_request_duration_seconds_sum counter",
      "# HELP bangbang_http_request_duration_seconds_count Timed HTTP responses.",
      "# TYPE bangbang_http_request_duration_seconds_count counter",
    );
    for (const [key, value] of [...durations.entries()].sort()) {
      const [method, route] = key.split("\u0000");
      const labels = `method="${escapeLabel(method)}",route="${escapeLabel(route)}"`;
      lines.push(`bangbang_http_request_duration_seconds_sum{${labels}} ${value.sum}`);
      lines.push(`bangbang_http_request_duration_seconds_count{${labels}} ${value.count}`);
    }
    for (const [name, rawValue] of Object.entries(gauges).sort()) {
      const safeName = String(name).replace(/[^a-zA-Z0-9_:]/g, "_");
      const value = Number(rawValue);
      if (Number.isFinite(value)) {
        const type = safeName.endsWith("_total") ? "counter" : "gauge";
        lines.push(`# TYPE bangbang_${safeName} ${type}`);
        lines.push(`bangbang_${safeName} ${value}`);
      }
    }
    return `${lines.join("\n")}\n`;
  }

  return { record, render };
}
