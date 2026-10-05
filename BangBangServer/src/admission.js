import { config } from "./config.js";
import { pool, withTransaction } from "./db.js";

const ADMISSION_LOCK_KEY = 2_026_071_700;

async function lockAdmission(client) {
  await client.query("SELECT pg_advisory_xact_lock($1)", [ADMISSION_LOCK_KEY]);
}

async function cleanupExpired(client) {
  await client.query("DELETE FROM online_presence WHERE lease_expires_at <= NOW()");
  await client.query("DELETE FROM login_queue WHERE expires_at <= NOW()");
  await client.query(
    `DELETE FROM login_queue q
      WHERE NOT EXISTS (
        SELECT 1 FROM sessions s
         WHERE s.id = q.session_id AND s.expires_at > NOW()
      )`,
  );
}

async function promoteQueuedPlayers(client) {
  const countResult = await client.query("SELECT COUNT(*)::int AS count FROM online_presence");
  const available = Math.max(0, config.maxOnlinePlayers - countResult.rows[0].count);
  if (available === 0) {
    return;
  }

  const queued = await client.query(
    `SELECT q.id, q.account_id, q.session_id
       FROM login_queue q
       JOIN sessions s ON s.id = q.session_id AND s.expires_at > NOW()
      ORDER BY q.enqueued_at, q.id
      LIMIT $1
      FOR UPDATE OF q SKIP LOCKED`,
    [available],
  );

  for (const entry of queued.rows) {
    await client.query(
      `INSERT INTO online_presence
         (account_id, session_id, lease_expires_at)
       VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 second'))
       ON CONFLICT (account_id) DO UPDATE
         SET session_id = EXCLUDED.session_id,
             admitted_at = NOW(),
             last_heartbeat_at = NOW(),
             lease_expires_at = EXCLUDED.lease_expires_at`,
      [entry.account_id, entry.session_id, config.presenceLeaseSeconds],
    );
    await client.query("DELETE FROM login_queue WHERE id = $1", [entry.id]);
  }
}

async function statusFor(client, account) {
  const presence = await client.query(
    `SELECT 1 FROM online_presence
      WHERE account_id = $1 AND session_id = $2 AND lease_expires_at > NOW()`,
    [account.id, account.session_id],
  );
  const onlineResult = await client.query(
    "SELECT COUNT(*)::int AS count FROM online_presence WHERE lease_expires_at > NOW()",
  );
  const online = onlineResult.rows[0].count;

  if (presence.rowCount === 1) {
    return {
      state: "admitted",
      online,
      capacity: config.maxOnlinePlayers,
      heartbeat_interval_seconds: config.heartbeatIntervalSeconds,
    };
  }

  const queueResult = await client.query(
    `SELECT q.id, q.enqueued_at,
            (SELECT COUNT(*)::int FROM login_queue) AS total_waiting,
            (SELECT COUNT(*)::int
               FROM login_queue ahead
              WHERE (ahead.enqueued_at, ahead.id) <= (q.enqueued_at, q.id)) AS position
       FROM login_queue q
      WHERE q.account_id = $1 AND q.session_id = $2`,
    [account.id, account.session_id],
  );

  if (queueResult.rowCount === 0) {
    return {
      state: "not_queued",
      online,
      capacity: config.maxOnlinePlayers,
      poll_after_ms: config.queuePollSeconds * 1000,
    };
  }

  const position = queueResult.rows[0].position;
  const disconnectCountdownResult = await client.query(
    `SELECT GREATEST(
              0,
              CEIL(EXTRACT(EPOCH FROM (lease_expires_at - NOW())))
            )::int AS seconds
       FROM online_presence
      WHERE lease_expires_at > NOW()
        AND last_heartbeat_at
              + (($1 + $2) * INTERVAL '1 second') <= NOW()
      ORDER BY lease_expires_at, account_id
      OFFSET $3
      LIMIT 1`,
    [
      config.heartbeatIntervalSeconds,
      config.queuePollSeconds,
      position - 1,
    ],
  );
  const disconnectCountdownActive = disconnectCountdownResult.rowCount === 1;

  return {
    state: "queued",
    position,
    total_waiting: queueResult.rows[0].total_waiting,
    online,
    capacity: config.maxOnlinePlayers,
    disconnect_countdown_active: disconnectCountdownActive,
    disconnect_countdown_seconds: disconnectCountdownActive
      ? disconnectCountdownResult.rows[0].seconds
      : 0,
    poll_after_ms: config.queuePollSeconds * 1000,
  };
}

export async function joinAdmission(account) {
  return withTransaction(async (client) => {
    await lockAdmission(client);
    await cleanupExpired(client);

    const currentPresence = await client.query(
      "SELECT 1 FROM online_presence WHERE account_id = $1 AND lease_expires_at > NOW()",
      [account.id],
    );
    if (currentPresence.rowCount === 1) {
      await client.query(
        `UPDATE online_presence
            SET session_id = $2,
                last_heartbeat_at = NOW(),
                lease_expires_at = NOW() + ($3 * INTERVAL '1 second')
          WHERE account_id = $1`,
        [account.id, account.session_id, config.presenceLeaseSeconds],
      );
      await client.query("DELETE FROM login_queue WHERE account_id = $1", [account.id]);
      return statusFor(client, account);
    }

    await client.query(
      `INSERT INTO login_queue (account_id, session_id, expires_at)
       VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 second'))
       ON CONFLICT (account_id) DO UPDATE
         SET session_id = EXCLUDED.session_id,
             expires_at = EXCLUDED.expires_at`,
      [account.id, account.session_id, config.queueTicketSeconds],
    );
    await promoteQueuedPlayers(client);
    return statusFor(client, account);
  });
}

export async function getAdmissionStatus(account) {
  return withTransaction(async (client) => {
    await lockAdmission(client);
    await client.query(
      `UPDATE login_queue
          SET expires_at = NOW() + ($3 * INTERVAL '1 second')
        WHERE account_id = $1 AND session_id = $2`,
      [account.id, account.session_id, config.queueTicketSeconds],
    );
    await cleanupExpired(client);
    await promoteQueuedPlayers(client);
    return statusFor(client, account);
  });
}

export async function heartbeatAdmission(account) {
  const result = await pool.query(
    `UPDATE online_presence
        SET last_heartbeat_at = NOW(),
            lease_expires_at = NOW() + ($3 * INTERVAL '1 second')
      WHERE account_id = $1 AND session_id = $2 AND lease_expires_at > NOW()`,
    [account.id, account.session_id, config.presenceLeaseSeconds],
  );
  return result.rowCount === 1;
}

export async function leaveAdmission(account) {
  await withTransaction(async (client) => {
    await lockAdmission(client);
    await client.query(
      "DELETE FROM online_presence WHERE account_id = $1 AND session_id = $2",
      [account.id, account.session_id],
    );
    await client.query(
      "DELETE FROM login_queue WHERE account_id = $1 AND session_id = $2",
      [account.id, account.session_id],
    );
    await cleanupExpired(client);
    await promoteQueuedPlayers(client);
  });
}

export async function hasAdmission(account) {
  const result = await pool.query(
    `SELECT 1 FROM online_presence
      WHERE account_id = $1 AND session_id = $2 AND lease_expires_at > NOW()`,
    [account.id, account.session_id],
  );
  return result.rowCount === 1;
}
