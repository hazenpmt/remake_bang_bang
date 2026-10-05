function readInteger(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? "", 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function readBoolean(name, fallback) {
  const value = process.env[name];
  if (value == null) {
    return fallback;
  }
  return value.toLowerCase() === "true" || value === "1";
}

export const config = Object.freeze({
  host: process.env.HOST ?? "127.0.0.1",
  port: readInteger("PORT", 8080),
  databaseUrl:
    process.env.DATABASE_URL ??
    "postgresql://bangbang:change_me@127.0.0.1:5432/bangbang",
  sessionDays: readInteger("SESSION_DAYS", 30),
  adminSessionHours: readInteger("ADMIN_SESSION_HOURS", 8),
  allowedOrigin: process.env.ALLOWED_ORIGIN ?? "*",
  maxOnlinePlayers: readInteger("MAX_ONLINE_PLAYERS", 100),
  presenceLeaseSeconds: readInteger("PRESENCE_LEASE_SECONDS", 30),
  heartbeatIntervalSeconds: readInteger("HEARTBEAT_INTERVAL_SECONDS", 10),
  queueTicketSeconds: readInteger("QUEUE_TICKET_SECONDS", 30),
  queuePollSeconds: readInteger("QUEUE_POLL_SECONDS", 3),
  loginRateLimit: readInteger("LOGIN_RATE_LIMIT", 8),
  loginRateWindowSeconds: readInteger("LOGIN_RATE_WINDOW_SECONDS", 60),
  loginAccountRateLimit: readInteger("LOGIN_ACCOUNT_RATE_LIMIT", 10),
  loginAccountRateWindowSeconds: readInteger(
    "LOGIN_ACCOUNT_RATE_WINDOW_SECONDS",
    300,
  ),
  queuePollRateLimit: readInteger("QUEUE_POLL_RATE_LIMIT", 30),
  worldChatResetOnServerStart: readBoolean(
    "WORLD_CHAT_RESET_ON_SERVER_START",
    true,
  ),
  registrationCooldownSeconds: readInteger(
    "REGISTRATION_COOLDOWN_SECONDS",
    10_800,
  ),
  registrationIpLimit: readInteger("REGISTRATION_IP_LIMIT", 5),
  registrationHashSecret: process.env.REGISTRATION_HASH_SECRET ?? "",
  webProxySecret: process.env.WEB_PROXY_SECRET ?? "",
  trustProxy: readBoolean("TRUST_PROXY", false),
  nodeEnvironment: (process.env.NODE_ENV ?? "development").toLowerCase(),
  rateLimitBackend: (
    process.env.RATE_LIMIT_BACKEND
    ?? (process.env.REDIS_URL ? "redis" : "memory")
  ).toLowerCase(),
  rateLimitKeySecret:
    process.env.RATE_LIMIT_KEY_SECRET
    ?? process.env.REGISTRATION_HASH_SECRET
    ?? "",
  rateLimitRedisUrl: process.env.REDIS_URL ?? "",
  rateLimitRedisConnectTimeoutMs: readInteger(
    "RATE_LIMIT_REDIS_CONNECT_TIMEOUT_MS",
    5_000,
  ),
  rateLimitPrefix: process.env.RATE_LIMIT_PREFIX ?? "bangbang:rate-limit",
  securityTelemetryFlushMs: readInteger("SECURITY_TELEMETRY_FLUSH_MS", 1_000),
  securityTelemetryBatchSize: readInteger("SECURITY_TELEMETRY_BATCH_SIZE", 100),
  securityTelemetryQueueLimit: readInteger("SECURITY_TELEMETRY_QUEUE_LIMIT", 5_000),
  metricsEnabled: readBoolean("METRICS_ENABLED", false),
  metricsBearerToken: process.env.METRICS_BEARER_TOKEN ?? "",
  contentStorageRoot: process.env.CONTENT_STORAGE_ROOT ?? new URL(
    "../content_storage",
    import.meta.url,
  ).pathname.replace(/^\/(?:([A-Za-z]:))/, "$1"),
  contentPublicBaseUrl: (process.env.CONTENT_PUBLIC_BASE_URL ?? "").replace(/\/+$/, ""),
  contentMaxImageBytes: readInteger(
    "CONTENT_MAX_IMAGE_BYTES",
    16 * 1024 * 1024,
  ),
  battleTickMs: readInteger("BATTLE_TICK_MS", 50),
  battleTickBatchSize: readInteger("BATTLE_TICK_BATCH_SIZE", 100),
  battleTickConcurrency: readInteger("BATTLE_TICK_CONCURRENCY", 8),
  battleRealtimeSnapshotMs: readInteger("BATTLE_REALTIME_SNAPSHOT_MS", 100),
  battleRealtimeFullSnapshotMs: readInteger(
    "BATTLE_REALTIME_FULL_SNAPSHOT_MS",
    5_000,
  ),
  battleRealtimeDeltaMaxRatioBasisPoints: readInteger(
    "BATTLE_REALTIME_DELTA_MAX_RATIO_BASIS_POINTS",
    8_500,
  ),
  battleRealtimeHeartbeatMs: readInteger("BATTLE_REALTIME_HEARTBEAT_MS", 10_000),
  battleRealtimeMessageLimit: readInteger("BATTLE_REALTIME_MESSAGE_LIMIT", 80),
  battleRealtimeMessageWindowMs: readInteger(
    "BATTLE_REALTIME_MESSAGE_WINDOW_MS",
    1_000,
  ),
  battleRealtimeMaxBufferedBytes: readInteger(
    "BATTLE_REALTIME_MAX_BUFFERED_BYTES",
    256 * 1024,
  ),
  battleRealtimeRequireTicket: readBoolean(
    "BATTLE_REALTIME_REQUIRE_TICKET",
    true,
  ),
  battleRealtimeTicketSeconds: readInteger(
    "BATTLE_REALTIME_TICKET_SECONDS",
    30,
  ),
  battlePublicRealtimeUrl: process.env.BATTLE_PUBLIC_REALTIME_URL ?? "",
  battleNodeId: process.env.BATTLE_NODE_ID ?? "local",
  battleWorkerNodeLeaseMs: readInteger("BATTLE_WORKER_NODE_LEASE_MS", 15_000),
  battleRuntimeEnabled: readBoolean("BATTLE_RUNTIME_ENABLED", true),
  battleMemoryWorkers: readBoolean("BATTLE_MEMORY_WORKERS", true),
  battleCheckpointMs: readInteger("BATTLE_CHECKPOINT_MS", 500),
  battleWorkerLeaseMs: readInteger("BATTLE_WORKER_LEASE_MS", 5_000),
  battleWorkerDiscoveryMs: readInteger("BATTLE_WORKER_DISCOVERY_MS", 1_000),
  battleWorkerLimit: readInteger("BATTLE_WORKER_LIMIT", 100),
});

if (config.registrationHashSecret.length < 32) {
  throw new Error(
    "REGISTRATION_HASH_SECRET must contain at least 32 characters. Run npm start to generate it.",
  );
}

if (config.webProxySecret && config.webProxySecret.length < 32) {
  throw new Error("WEB_PROXY_SECRET must contain at least 32 characters.");
}

if (!new Set(["memory", "redis"]).has(config.rateLimitBackend)) {
  throw new Error("RATE_LIMIT_BACKEND must be memory or redis.");
}

if (config.rateLimitKeySecret.length < 32) {
  throw new Error("RATE_LIMIT_KEY_SECRET must contain at least 32 characters.");
}

if (config.rateLimitBackend === "redis" && !config.rateLimitRedisUrl) {
  throw new Error("REDIS_URL is required when RATE_LIMIT_BACKEND=redis.");
}

if (
  config.nodeEnvironment === "production"
  && config.rateLimitBackend !== "redis"
) {
  throw new Error("Production requires RATE_LIMIT_BACKEND=redis.");
}

if (config.metricsBearerToken && config.metricsBearerToken.length < 32) {
  throw new Error("METRICS_BEARER_TOKEN must contain at least 32 characters.");
}

if (
  config.nodeEnvironment === "production"
  && (!config.metricsEnabled || !config.metricsBearerToken)
) {
  throw new Error("Production requires protected metrics.");
}

if (config.nodeEnvironment === "production" && config.allowedOrigin === "*") {
  throw new Error("Production requires an explicit ALLOWED_ORIGIN.");
}

if (
  config.nodeEnvironment === "production"
  && config.webProxySecret.length < 32
) {
  throw new Error("Production requires WEB_PROXY_SECRET for signed client IP forwarding.");
}

if (
  config.nodeEnvironment === "production"
  && !config.battlePublicRealtimeUrl.startsWith("wss://")
) {
  throw new Error("Production requires a wss:// BATTLE_PUBLIC_REALTIME_URL.");
}

if (
  config.nodeEnvironment === "production"
  && !config.contentPublicBaseUrl.startsWith("https://")
) {
  throw new Error("Production requires an https:// CONTENT_PUBLIC_BASE_URL.");
}

if (
  config.battlePublicRealtimeUrl
  && !/^wss?:\/\/[^\s]+\/api\/realtime\/battle$/.test(
    config.battlePublicRealtimeUrl,
  )
) {
  throw new Error(
    "BATTLE_PUBLIC_REALTIME_URL must be a full ws:// or wss:// URL ending in /api/realtime/battle.",
  );
}
