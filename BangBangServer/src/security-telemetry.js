import { createHmac } from "node:crypto";

const VALID_SEVERITIES = new Set(["info", "low", "medium", "high", "critical"]);
const VALID_SOURCES = new Set(["http", "websocket", "battle", "economy", "system"]);
const SENSITIVE_KEY = /(authorization|password|secret|session|ticket|token|cookie)/i;

function text(value, limit) {
  return String(value ?? "").trim().slice(0, limit);
}

function positiveId(value) {
  const result = Number(value);
  return Number.isSafeInteger(result) && result > 0 ? result : null;
}

function redact(value, depth = 0) {
  if (depth > 4) {
    return "[depth-limit]";
  }
  if (Array.isArray(value)) {
    return value.slice(0, 32).map((entry) => redact(entry, depth + 1));
  }
  if (!value || typeof value !== "object") {
    if (typeof value === "string") {
      return value.slice(0, 512);
    }
    return value;
  }
  const result = {};
  for (const [key, entry] of Object.entries(value).slice(0, 64)) {
    result[key] = SENSITIVE_KEY.test(key) ? "[redacted]" : redact(entry, depth + 1);
  }
  return result;
}

function normalizeDetails(value) {
  const redacted = redact(value ?? {});
  const encoded = JSON.stringify(redacted);
  if (Buffer.byteLength(encoded) <= 7_500) {
    return redacted;
  }
  return { truncated: true, original_bytes: Buffer.byteLength(encoded) };
}

export function createSecurityTelemetry(options = {}) {
  const query = options.query;
  if (typeof query !== "function") {
    throw new Error("Security telemetry requires a query function.");
  }
  const nodeId = text(options.nodeId ?? "local", 96) || "local";
  const hashSecret = String(options.hashSecret ?? "");
  const flushMs = Math.max(100, Number(options.flushMs ?? 1_000));
  const batchSize = Math.max(1, Number(options.batchSize ?? 100));
  const queueLimit = Math.max(batchSize, Number(options.queueLimit ?? 5_000));
  if (hashSecret.length < 32) {
    throw new Error("Security telemetry hash secret must contain at least 32 characters.");
  }

  const queue = [];
  let timer = null;
  let flushPromise = null;
  let recorded = 0;
  let persisted = 0;
  let dropped = 0;
  let lastFlushAt = null;
  let lastErrorAt = null;
  const severityTotals = Object.fromEntries(
    [...VALID_SEVERITIES].map((severity) => [severity, 0]),
  );

  function hashIp(ip) {
    if (!ip) {
      return null;
    }
    return createHmac("sha256", hashSecret).update(String(ip)).digest("hex");
  }

  function record(event = {}) {
    recorded += 1;
    if (queue.length >= queueLimit) {
      dropped += 1;
      return false;
    }
    const severity = VALID_SEVERITIES.has(event.severity)
      ? event.severity
      : "medium";
    const source = VALID_SOURCES.has(event.source) ? event.source : "system";
    severityTotals[severity] += 1;
    queue.push({
      event_type: text(event.eventType || "unknown", 96) || "unknown",
      severity,
      source,
      node_id: nodeId,
      account_id: positiveId(event.accountId),
      session_id: positiveId(event.sessionId),
      match_id: positiveId(event.matchId),
      route: text(event.route, 160) || null,
      source_ip_hash: hashIp(event.ip),
      details: normalizeDetails(event.details),
      occurred_at: event.occurredAt instanceof Date
        ? event.occurredAt.toISOString()
        : new Date().toISOString(),
    });
    return true;
  }

  async function flush() {
    if (flushPromise) {
      return flushPromise;
    }
    if (queue.length === 0) {
      return;
    }
    const batch = queue.splice(0, batchSize);
    flushPromise = (async () => {
      try {
        await query(
          `INSERT INTO security_events
             (event_type, severity, source, node_id, account_id, session_id,
              match_id, route, source_ip_hash, details, occurred_at)
           SELECT event_type, severity, source, node_id, account_id, session_id,
                  match_id, route, source_ip_hash, details, occurred_at
             FROM jsonb_to_recordset($1::jsonb) AS event(
               event_type varchar, severity varchar, source varchar,
               node_id varchar, account_id bigint, session_id bigint,
               match_id bigint, route varchar, source_ip_hash char(64),
               details jsonb, occurred_at timestamptz
             )`,
          [JSON.stringify(batch)],
        );
        persisted += batch.length;
        lastFlushAt = new Date().toISOString();
      } catch (error) {
        lastErrorAt = new Date().toISOString();
        const available = Math.max(0, queueLimit - queue.length);
        queue.unshift(...batch.slice(0, available));
        dropped += Math.max(0, batch.length - available);
        throw error;
      } finally {
        flushPromise = null;
      }
    })();
    return flushPromise;
  }

  function start() {
    if (timer) {
      return;
    }
    timer = setInterval(() => {
      flush().catch((error) => {
        console.error("Security telemetry flush failed:", error.message);
      });
    }, flushMs);
    timer.unref();
  }

  async function close() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    while (queue.length > 0) {
      await flush();
    }
  }

  function health() {
    return {
      queued: queue.length,
      recorded,
      persisted,
      dropped,
      last_flush_at: lastFlushAt,
      last_error_at: lastErrorAt,
      severity_totals: { ...severityTotals },
    };
  }

  return { record, flush, start, close, health };
}
