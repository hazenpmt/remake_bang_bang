import { createHmac } from "node:crypto";
import { config } from "./config.js";

const DEVICE_ID_PATTERN = /^[a-zA-Z0-9_-]{32,128}$/;

function identifierHash(value) {
  return createHmac("sha256", config.registrationHashSecret)
    .update(value)
    .digest("hex");
}

function lockKey(hash) {
  return BigInt(`0x${hash.slice(0, 15)}`);
}

export function normalizeDeviceId(value) {
  const deviceId = String(value ?? "").trim();
  return DEVICE_ID_PATTERN.test(deviceId) ? deviceId : "";
}

export async function checkRegistrationCooldown(client, ip, deviceId) {
  const ipHash = identifierHash(ip);
  const deviceHash = identifierHash(deviceId);
  const keys = [lockKey(ipHash), lockKey(deviceHash)].sort((a, b) =>
    a < b ? -1 : a > b ? 1 : 0,
  );

  for (const key of keys) {
    await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [
      key.toString(),
    ]);
  }

  const result = await client.query(
    `WITH recent_ip AS (
       SELECT created_at
         FROM account_registrations
        WHERE ip_hash = $1
          AND created_at > NOW() - ($3 * INTERVAL '1 second')
     ), recent_device AS (
       SELECT created_at
         FROM account_registrations
        WHERE device_hash = $2
          AND created_at > NOW() - ($3 * INTERVAL '1 second')
     )
     SELECT (SELECT COUNT(*)::int FROM recent_ip) AS ip_count,
            COALESCE(
              GREATEST(0, CEIL(EXTRACT(EPOCH FROM (
                (SELECT MIN(created_at) FROM recent_ip)
                + ($3 * INTERVAL '1 second') - NOW()
              )))::int),
              0
            ) AS ip_retry_after_seconds,
            COALESCE(
              GREATEST(0, CEIL(EXTRACT(EPOCH FROM (
                (SELECT MAX(created_at) FROM recent_device)
                + ($3 * INTERVAL '1 second') - NOW()
              )))::int),
              0
            ) AS device_retry_after_seconds`,
    [ipHash, deviceHash, config.registrationCooldownSeconds],
  );

  const row = result.rows[0];
  const ipLimitReached = row.ip_count >= config.registrationIpLimit;
  const deviceLimitReached = row.device_retry_after_seconds > 0;
  const retryAfterSeconds = Math.max(
    ipLimitReached ? row.ip_retry_after_seconds : 0,
    deviceLimitReached ? row.device_retry_after_seconds : 0,
  );

  return {
    allowed: !ipLimitReached && !deviceLimitReached,
    retryAfterSeconds,
    reason: deviceLimitReached ? "device" : ipLimitReached ? "ip" : "",
    ipHash,
    deviceHash,
  };
}

export async function recordRegistration(client, accountId, policy) {
  await client.query(
    `INSERT INTO account_registrations (account_id, ip_hash, device_hash)
     VALUES ($1, $2, $3)`,
    [accountId, policy.ipHash, policy.deviceHash],
  );
}
