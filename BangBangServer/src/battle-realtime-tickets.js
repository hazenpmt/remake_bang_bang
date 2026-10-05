import { createSessionToken, hashSessionToken } from "./security.js";
import { pool, withTransaction } from "./db.js";

export class BattleRealtimeTicketError extends Error {
  constructor(status, code, message, retryAfterMs = 0) {
    super(message);
    this.status = status;
    this.code = code;
    if (retryAfterMs > 0) {
      this.retryAfterMs = retryAfterMs;
    }
  }
}

function ticketError(status, code, message, retryAfterMs = 0) {
  throw new BattleRealtimeTicketError(status, code, message, retryAfterMs);
}

function ticketHeader(request) {
  const value = request.headers["x-battle-ticket"];
  return typeof value === "string" ? value.trim() : "";
}

async function loadBattleRoute(accountId) {
  const result = await pool.query(
    `SELECT match.id AS match_id,
            match.phase,
            match.is_test,
            match.battle_worker_id,
            match.battle_worker_epoch,
            match.battle_worker_lease_until,
            node.public_realtime_url,
            node.lease_until AS node_lease_until
       FROM game_match_participants participant
       JOIN game_matches match ON match.id = participant.match_id
       LEFT JOIN battle_worker_nodes node
         ON node.worker_id = match.battle_worker_id
      WHERE participant.account_id = $1
        AND NOT participant.is_bot
        AND match.phase <> 'cancelled'
      ORDER BY match.created_at DESC, match.id DESC
      LIMIT 1`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    ticketError(404, "BATTLE_NOT_FOUND", "Không tìm thấy trận đấu đang hoạt động.");
  }
  const route = result.rows[0];
  if (route.is_test) {
    ticketError(
      409,
      "BATTLE_SANDBOX_LOCAL",
      "Sandbox TEST không mở kết nối realtime online.",
    );
  }
  if (route.phase !== "active") {
    ticketError(
      409,
      "BATTLE_REALTIME_FINISHED",
      "Trận đấu đã kết thúc; hãy dùng snapshot kết quả qua HTTP.",
    );
  }
  return route;
}

function leaseActive(value) {
  const timestamp = new Date(value ?? 0).getTime();
  return Number.isFinite(timestamp) && timestamp > Date.now();
}

async function resolveBattleRoute(accountId, localRegistry) {
  let route = await loadBattleRoute(accountId);
  const owned = route.battle_worker_id && leaseActive(route.battle_worker_lease_until);
  if (!owned) {
    if (!localRegistry) {
      ticketError(
        503,
        "BATTLE_ROUTE_UNAVAILABLE",
        "Chưa có match worker nhận trận đấu này.",
        500,
      );
    }
    await localRegistry.getSnapshot(accountId);
    route = await loadBattleRoute(accountId);
  }
  if (!route.battle_worker_id || !leaseActive(route.battle_worker_lease_until)) {
    ticketError(
      503,
      "BATTLE_ROUTE_UNAVAILABLE",
      "Match worker chưa sẵn sàng.",
      500,
    );
  }
  const local = (
    localRegistry
    && String(route.battle_worker_id) === String(localRegistry.instanceId)
  );
  if (!local && !leaseActive(route.node_lease_until)) {
    ticketError(
      503,
      "BATTLE_ROUTE_UNAVAILABLE",
      "Không tìm thấy node đang giữ trận đấu.",
      500,
    );
  }
  if (!local && !route.public_realtime_url) {
    ticketError(
      503,
      "BATTLE_ROUTE_URL_MISSING",
      "Node giữ trận chưa công bố địa chỉ realtime.",
      1_000,
    );
  }
  return route;
}

export async function issueBattleRealtimeTicket(
  account,
  localRegistry,
  options = {},
) {
  const lifetimeSeconds = Math.max(5, Number(options.lifetimeSeconds ?? 30));
  const route = await resolveBattleRoute(account.id, localRegistry);
  const token = createSessionToken();
  const expiresAt = new Date(Date.now() + lifetimeSeconds * 1_000);
  const local = (
    localRegistry
    && String(route.battle_worker_id) === String(localRegistry.instanceId)
  );
  const websocketUrl = local
    ? String(options.localPublicRealtimeUrl ?? "")
    : String(route.public_realtime_url ?? "");

  await withTransaction(async (client) => {
    const verified = await client.query(
      `SELECT 1
         FROM sessions session
         JOIN accounts account ON account.id = session.account_id
         JOIN game_match_participants participant
           ON participant.account_id = account.id
          AND NOT participant.is_bot
         JOIN game_matches match ON match.id = participant.match_id
        WHERE session.id = $1
          AND session.account_id = $2
          AND session.expires_at > NOW()
          AND account.status = 'active'
          AND match.id = $3
          AND match.phase = 'active'
          AND NOT match.is_test
          AND match.battle_worker_id = $4
          AND match.battle_worker_epoch = $5
          AND match.battle_worker_lease_until > NOW()
        FOR SHARE OF session, account, participant, match`,
      [
        account.session_id,
        account.id,
        route.match_id,
        route.battle_worker_id,
        route.battle_worker_epoch,
      ],
    );
    if (verified.rowCount !== 1) {
      ticketError(
        409,
        "BATTLE_ROUTE_CHANGED",
        "Route trận đấu vừa thay đổi; hãy xin lại vé.",
        250,
      );
    }
    await client.query(
      `INSERT INTO battle_realtime_tickets (
         token_hash, account_id, session_id, match_id,
         route_worker_id, worker_epoch, expires_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        hashSessionToken(token),
        account.id,
        account.session_id,
        route.match_id,
        route.battle_worker_id,
        route.battle_worker_epoch,
        expiresAt,
      ],
    );
    await client.query(
      `DELETE FROM battle_realtime_tickets
        WHERE expires_at < NOW() - INTERVAL '1 hour'`,
    );
  });

  return {
    ticket: token,
    expires_at: expiresAt.toISOString(),
    websocket_url: websocketUrl || null,
    match_id: String(route.match_id),
    state_epoch: Number(route.battle_worker_epoch),
  };
}

export async function authenticateBattleRealtimeTicket(
  request,
  localWorkerId,
) {
  const token = ticketHeader(request);
  if (!token) {
    ticketError(401, "BATTLE_TICKET_REQUIRED", "Thiếu vé kết nối trận đấu.");
  }
  const result = await withTransaction(async (client) => client.query(
    `UPDATE battle_realtime_tickets ticket
        SET used_at = NOW()
       FROM sessions session,
            accounts account,
            game_matches match,
            game_match_participants participant
      WHERE ticket.token_hash = $1
        AND ticket.used_at IS NULL
        AND ticket.expires_at > NOW()
        AND ticket.route_worker_id = $2
        AND session.id = ticket.session_id
        AND session.account_id = ticket.account_id
        AND session.expires_at > NOW()
        AND account.id = ticket.account_id
        AND account.status = 'active'
        AND match.id = ticket.match_id
        AND match.phase = 'active'
        AND match.battle_worker_id = ticket.route_worker_id
        AND match.battle_worker_epoch = ticket.worker_epoch
        AND match.battle_worker_lease_until > NOW()
        AND participant.match_id = match.id
        AND participant.account_id = ticket.account_id
        AND NOT participant.is_bot
      RETURNING account.id,
                account.username,
                account.role,
                session.id AS session_id,
                match.id AS match_id,
                ticket.worker_epoch`,
    [hashSessionToken(token), localWorkerId],
  ));
  if (result.rowCount !== 1) {
    ticketError(
      401,
      "BATTLE_TICKET_INVALID",
      "Vé kết nối đã hết hạn, đã dùng hoặc không đúng route.",
    );
  }
  return result.rows[0];
}
