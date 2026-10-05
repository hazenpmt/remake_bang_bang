import assert from "node:assert/strict";
import test from "node:test";

import {
  createRateLimiter,
  RateLimitUnavailableError,
} from "../src/rate-limiter.js";

const TEST_SECRET = "test-rate-limit-secret-that-is-long-enough";

test("memory rate limiter shares a fixed window by logical key", async () => {
  const limiter = createRateLimiter({
    backend: "memory",
    keySecret: TEST_SECRET,
  });
  await limiter.start();
  assert.equal((await limiter.consume("login:127.0.0.1", 2, 10_000)).allowed, true);
  assert.equal((await limiter.consume("login:127.0.0.1", 2, 10_000)).allowed, true);
  const rejected = await limiter.consume("login:127.0.0.1", 2, 10_000);
  assert.equal(rejected.allowed, false);
  assert.ok(rejected.retryAfterMs > 0);
  assert.equal((await limiter.consume("login:127.0.0.2", 2, 10_000)).allowed, true);
  assert.deepEqual(limiter.health(), {
    backend: "memory",
    ready: true,
    last_error_at: null,
  });
  await limiter.close();
  await assert.rejects(
    () => limiter.consume("login:127.0.0.1", 2, 10_000),
    RateLimitUnavailableError,
  );
});

test("redis backend requires an explicit URL", () => {
  assert.throws(
    () => createRateLimiter({
      backend: "redis",
      keySecret: TEST_SECRET,
    }),
    /REDIS_URL/,
  );
});

test("two redis-backed limiters share the same counter and fail closed", async () => {
  const counters = new Map();
  let available = true;
  function fakeClient() {
    return {
      isReady: false,
      isOpen: false,
      on() {},
      async connect() {
        this.isReady = true;
        this.isOpen = true;
      },
      async eval(_script, options) {
        if (!available) {
          throw new Error("redis down");
        }
        const key = options.keys[0];
        const remaining = counters.get(key) ?? Number(options.arguments[0]);
        const allowed = remaining >= 1 ? 1 : 0;
        counters.set(key, allowed ? remaining - 1 : remaining);
        return [allowed, Math.max(0, remaining - allowed) * 1_000_000, allowed ? 0 : 1000];
      },
      async quit() {
        this.isReady = false;
        this.isOpen = false;
      },
    };
  }
  const options = {
    backend: "redis",
    redisUrl: "redis://fixture",
    keySecret: TEST_SECRET,
    createRedisClient: fakeClient,
  };
  const first = createRateLimiter(options);
  const second = createRateLimiter(options);
  await Promise.all([first.start(), second.start()]);
  assert.equal((await first.consume("account:7", 2, 10_000)).allowed, true);
  assert.equal((await second.consume("account:7", 2, 10_000)).allowed, true);
  assert.equal((await first.consume("account:7", 2, 10_000)).allowed, false);
  available = false;
  await assert.rejects(
    () => second.consume("account:8", 2, 10_000),
    RateLimitUnavailableError,
  );
  await Promise.all([first.close(), second.close()]);
});
