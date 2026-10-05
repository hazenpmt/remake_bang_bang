import { createHmac } from "node:crypto";

import { createClient } from "redis";

const TOKEN_BUCKET_SCRIPT = `
local clock = redis.call('TIME')
local now = (tonumber(clock[1]) * 1000) + math.floor(tonumber(clock[2]) / 1000)
local capacity = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local state = redis.call('HMGET', KEYS[1], 'tokens', 'updated_at')
local tokens = tonumber(state[1]) or capacity
local updated = tonumber(state[2]) or now
local elapsed = math.max(0, now - updated)
tokens = math.min(capacity, tokens + (elapsed * capacity / window))
local allowed = 0
local retry = 0
if tokens >= 1 then
  tokens = tokens - 1
  allowed = 1
else
  retry = math.ceil((1 - tokens) * window / capacity)
end
redis.call('HSET', KEYS[1], 'tokens', tokens, 'updated_at', now)
redis.call('PEXPIRE', KEYS[1], window * 2)
return {allowed, math.floor(tokens * 1000000), retry}
`;

export class RateLimitUnavailableError extends Error {
  constructor(message = "Shared rate limiter is unavailable.") {
    super(message);
    this.code = "RATE_LIMIT_UNAVAILABLE";
  }
}

function positiveInteger(value, fallback) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : fallback;
}

function hashKey(secret, value) {
  return createHmac("sha256", secret).update(String(value)).digest("hex");
}

export function createRateLimiter(options = {}) {
  const backend = String(options.backend ?? "memory").toLowerCase();
  const prefix = String(options.prefix ?? "bangbang:rate-limit");
  const keySecret = String(options.keySecret ?? "");
  const redisUrl = String(options.redisUrl ?? "");
  const redisClientFactory = options.createRedisClient ?? createClient;
  const connectTimeoutMs = positiveInteger(options.connectTimeoutMs, 5_000);
  if (keySecret.length < 32) {
    throw new Error("Rate-limit key secret must contain at least 32 characters.");
  }
  if (!new Set(["memory", "redis"]).has(backend)) {
    throw new Error("RATE_LIMIT_BACKEND must be memory or redis.");
  }
  if (backend === "redis" && !redisUrl) {
    throw new Error("REDIS_URL is required when RATE_LIMIT_BACKEND=redis.");
  }

  const buckets = new Map();
  let redis = null;
  let started = false;
  let lastErrorAt = null;

  function publicKey(key) {
    return `${prefix}:${hashKey(keySecret, key)}`;
  }

  function consumeMemory(key, limit, windowMs) {
    const now = Date.now();
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = { tokens: limit, updatedAt: now, expiresAt: now + windowMs * 2 };
      buckets.set(key, bucket);
    }
    const elapsed = Math.max(0, now - bucket.updatedAt);
    bucket.tokens = Math.min(
      limit,
      bucket.tokens + elapsed * limit / windowMs,
    );
    bucket.updatedAt = now;
    bucket.expiresAt = now + windowMs * 2;
    const allowed = bucket.tokens >= 1;
    if (allowed) {
      bucket.tokens -= 1;
    }
    if (buckets.size > 10_000) {
      for (const [bucketKey, value] of buckets) {
        if (value.expiresAt <= now) {
          buckets.delete(bucketKey);
        }
      }
    }
    return {
      allowed,
      remaining: Math.max(0, Math.floor(bucket.tokens)),
      limit,
      retryAfterMs: allowed
        ? 0
        : Math.max(1, Math.ceil((1 - bucket.tokens) * windowMs / limit)),
    };
  }

  async function start() {
    if (started) {
      return;
    }
    if (backend === "redis") {
      redis = redisClientFactory({
        url: redisUrl,
        socket: { connectTimeout: connectTimeoutMs },
      });
      redis.on("error", (error) => {
        lastErrorAt = new Date().toISOString();
        console.error("Redis rate limiter error:", error.message);
      });
      try {
        await redis.connect();
      } catch (error) {
        try {
          await redis.disconnect?.();
        } catch {}
        redis = null;
        throw new RateLimitUnavailableError(error.message);
      }
      if (!redis.isReady) {
        throw new RateLimitUnavailableError();
      }
    }
    started = true;
  }

  async function consume(key, rawLimit, rawWindowMs) {
    if (!started) {
      throw new RateLimitUnavailableError("Rate limiter has not started.");
    }
    const limit = positiveInteger(rawLimit, 1);
    const windowMs = positiveInteger(rawWindowMs, 1_000);
    const storageKey = publicKey(key);
    if (backend === "memory") {
      return consumeMemory(storageKey, limit, windowMs);
    }
    if (!redis?.isReady) {
      throw new RateLimitUnavailableError();
    }
    try {
      const result = await redis.eval(TOKEN_BUCKET_SCRIPT, {
        keys: [storageKey],
        arguments: [String(limit), String(windowMs)],
      });
      const allowed = Number(result?.[0]);
      const remainingMicros = Number(result?.[1]);
      const retryAfterMs = Number(result?.[2]);
      if (
        !Number.isFinite(allowed)
        || !Number.isFinite(remainingMicros)
        || !Number.isFinite(retryAfterMs)
      ) {
        throw new Error("Redis returned an invalid rate-limit result.");
      }
      return {
        allowed: allowed === 1,
        remaining: Math.max(0, Math.floor(remainingMicros / 1_000_000)),
        limit,
        retryAfterMs: Math.max(0, retryAfterMs),
      };
    } catch (error) {
      lastErrorAt = new Date().toISOString();
      throw new RateLimitUnavailableError(error.message);
    }
  }

  async function close() {
    buckets.clear();
    started = false;
    if (redis?.isOpen) {
      await redis.quit();
    }
    redis = null;
  }

  function health() {
    return {
      backend,
      ready: started && (backend === "memory" || Boolean(redis?.isReady)),
      last_error_at: lastErrorAt,
    };
  }

  return { start, consume, close, health };
}
