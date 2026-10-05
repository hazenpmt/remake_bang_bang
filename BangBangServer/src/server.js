import { randomUUID, timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";
import { isIP } from "node:net";
import { config } from "./config.js";
import { pool, withReadTransaction, withTransaction } from "./db.js";
import {
  createSessionToken,
  hashPassword,
  hashSessionToken,
  verifyPassword,
} from "./security.js";
import {
  validateChatMessage,
  validateCharacter,
  validateCredentials,
  validateLoginCredentials,
} from "./validation.js";
import {
  getAdmissionStatus,
  hasAdmission,
  heartbeatAdmission,
  joinAdmission,
  leaveAdmission,
} from "./admission.js";
import {
  checkRegistrationCooldown,
  normalizeDeviceId,
  recordRegistration,
} from "./registration-policy.js";
import { applyTankSkinCollectionBonus } from "./tank-skin-bonus.js";
import { experienceMaxForLevel } from "./character-levels.js";
import {
  applyMilitaryRankCooldowns,
  buildMilitaryRankSummary,
  militaryRankBonusSource,
} from "./military-rank.js";
import { STARTER_CURRENCY_BALANCE } from "./starter-currency.js";
import {
  EconomyError,
  loadInventory,
  loadShopCatalog,
  purchaseOffer,
  validatePurchaseRequest,
} from "./economy.js";
import {
  GameRoomError,
  cancelGameRoomMatchmaking,
  confirmGameMatch,
  createGameRoom,
  currentGameMatch,
  currentGameRoom,
  deployGameMatchTank,
  equipGameMatchSkin,
  joinGameRoom,
  leaveGameRoom,
  listGameMaps,
  listGameMatchBattleMessages,
  listGameMatchTeamMessages,
  listGameRooms,
  quickJoinGameRoom,
  removeAccountFromGameRoom,
  reportGameMatchLoad,
  sendGameMatchBattleMessage,
  sendGameMatchTeamMessage,
  selectGameRoomMap,
  selectGameMatchTank,
  startGameRoom,
} from "./game-rooms.js";
import {
  BattleRuntimeError,
  getBattleSnapshot,
  readBattleSnapshot,
  submitBattleCommand,
} from "./battle-runtime.js";
import { startBattleTicker } from "./battle-ticker.js";
import { attachBattleRealtime } from "./battle-realtime.js";
import { createBattleMemoryWorkerRegistry } from "./battle-memory-workers.js";
import {
  authenticateBattleRealtimeTicket,
  issueBattleRealtimeTicket,
} from "./battle-realtime-tickets.js";
import {
  createRateLimiter,
  RateLimitUnavailableError,
} from "./rate-limiter.js";
import { createSecurityTelemetry } from "./security-telemetry.js";
import { createHttpMetrics } from "./metrics.js";
import { CatalogValidationError } from "./shop-catalog.js";
import {
  ContentDeliveryError,
  materializeManifest,
  readContentFile,
  readPublishedManifest,
  saveImageAsset,
} from "./content-delivery.js";
import {
  publishShopDraft,
  readShopEditorState,
  rollbackShopRelease,
  saveShopDraft,
  ShopPublishingError,
} from "./shop-publishing.js";

const JSON_LIMIT = 32 * 1024;
const SHOP_DRAFT_JSON_LIMIT = 1024 * 1024;
const BATTLE_CHAT_MESSAGE_MAX_LENGTH = 64;
const rateLimiter = createRateLimiter({
  backend: config.rateLimitBackend,
  keySecret: config.rateLimitKeySecret,
  redisUrl: config.rateLimitRedisUrl,
  connectTimeoutMs: config.rateLimitRedisConnectTimeoutMs,
  prefix: config.rateLimitPrefix,
});
await rateLimiter.start();
const securityTelemetry = createSecurityTelemetry({
  query: (sql, parameters) => pool.query(sql, parameters),
  nodeId: config.battleNodeId,
  hashSecret: config.registrationHashSecret,
  flushMs: config.securityTelemetryFlushMs,
  batchSize: config.securityTelemetryBatchSize,
  queueLimit: config.securityTelemetryQueueLimit,
});
securityTelemetry.start();
const httpMetrics = createHttpMetrics();
const serverStartedAt = Date.now();
let shuttingDown = false;
const battleMemoryWorkers = (
  config.battleRuntimeEnabled && config.battleMemoryWorkers
)
  ? createBattleMemoryWorkerRegistry()
  : null;
const battleService = battleMemoryWorkers ?? {
  getSnapshot: getBattleSnapshot,
  readSnapshot: readBattleSnapshot,
  submitCommand: submitBattleCommand,
};
const dummyPasswordHash = await hashPassword(
  `not-an-account-${createSessionToken()}`,
);

class ApiError extends Error {
  constructor(status, code, message, retryAfter = 0) {
    super(message);
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

function sendJson(response, status, data, extraHeaders = {}) {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": config.allowedOrigin,
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, X-Device-Id, Idempotency-Key, "
      + "X-Asset-Id, X-Original-Filename",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    ...extraHeaders,
  });
  response.end(JSON.stringify(data));
}

function clientIp(request) {
  let value = request.socket.remoteAddress ?? "unknown";
  const proxySecret = request.headers["x-web-proxy-secret"];
  const clientAddress = request.headers["x-client-ip"];
  if (
    config.webProxySecret &&
    typeof proxySecret === "string" &&
    typeof clientAddress === "string"
  ) {
    const expected = Buffer.from(config.webProxySecret);
    const received = Buffer.from(proxySecret);
    if (
      expected.length === received.length &&
      timingSafeEqual(expected, received) &&
      isIP(clientAddress.trim())
    ) {
      value = clientAddress.trim();
    }
  }
  if (config.trustProxy) {
    const forwarded = request.headers["x-forwarded-for"];
    if (typeof forwarded === "string" && forwarded.trim()) {
      value = forwarded.split(",", 1)[0].trim();
    }
  }
  return value.startsWith("::ffff:") ? value.slice(7) : value;
}

function requestRoute(request) {
  try {
    return `${request.method} ${new URL(request.url, "http://localhost").pathname}`;
  } catch {
    return `${request.method ?? "UNKNOWN"} invalid-url`;
  }
}

function metricsAuthorized(request) {
  if (!config.metricsBearerToken) {
    return false;
  }
  const token = bearerToken(request);
  const expected = Buffer.from(config.metricsBearerToken);
  const received = Buffer.from(token);
  return expected.length === received.length && timingSafeEqual(expected, received);
}

function operationalGauges() {
  const telemetry = securityTelemetry.health();
  const memory = process.memoryUsage();
  return {
    process_uptime_seconds: Math.floor((Date.now() - serverStartedAt) / 1_000),
    process_resident_memory_bytes: memory.rss,
    process_heap_used_bytes: memory.heapUsed,
    realtime_connections: battleRealtime?.connectionCount?.() ?? 0,
    security_telemetry_queued: telemetry.queued,
    security_telemetry_dropped_total: telemetry.dropped,
    security_events_high_total: telemetry.severity_totals?.high ?? 0,
    security_events_critical_total: telemetry.severity_totals?.critical ?? 0,
    battle_workers: battleMemoryWorkers?.stats?.().workers ?? 0,
    shutting_down: shuttingDown ? 1 : 0,
  };
}

function cooldownMessage(seconds, reason) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.max(1, Math.ceil((seconds % 3600) / 60));
  const time = hours > 0 ? `${hours} giờ ${minutes} phút` : `${minutes} phút`;
  const rule = reason === "ip"
    ? `IP này đã tạo đủ ${config.registrationIpLimit} tài khoản trong 3 giờ.`
    : "Mã cài đặt này đã tạo một tài khoản trong 3 giờ.";
  return `${rule} Hãy thử lại sau khoảng ${time}.`;
}

async function consumeRateLimit(key, limit, windowSeconds) {
  let result;
  try {
    result = await rateLimiter.consume(key, limit, windowSeconds * 1_000);
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      throw new ApiError(
        503,
        "RATE_LIMIT_UNAVAILABLE",
        "Máy chủ bảo vệ lưu lượng đang tạm thời không sẵn sàng.",
        1,
      );
    }
    throw error;
  }
  if (!result.allowed) {
    const retryAfter = Math.max(1, Math.ceil(result.retryAfterMs / 1_000));
    throw new ApiError(
      429,
      "RATE_LIMITED",
      `Bạn thao tác quá nhanh. Hãy thử lại sau ${retryAfter} giây.`,
      retryAfter,
    );
  }
}

async function readBody(request, limit) {
  const chunks = [];
  let size = 0;

  for await (const chunk of request) {
    size += chunk.length;
    if (size > limit) {
      throw new ApiError(413, "BODY_TOO_LARGE", "Dữ liệu gửi lên quá lớn.");
    }
    chunks.push(chunk);
  }

  return Buffer.concat(chunks);
}

async function readJson(request, limit = JSON_LIMIT) {
  const body = await readBody(request, limit);
  if (body.length === 0) return {};
  try {
    return JSON.parse(body.toString("utf8"));
  } catch {
    throw new ApiError(400, "INVALID_JSON", "Dữ liệu JSON không hợp lệ.");
  }
}

function bearerToken(request) {
  const header = request.headers.authorization ?? "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

export async function requireSession(request, client = pool) {
  const token = bearerToken(request);
  if (!token) {
    throw new ApiError(401, "UNAUTHORIZED", "Bạn chưa đăng nhập.");
  }

  const result = await client.query(
    `SELECT a.id, a.username, a.role, s.id AS session_id
       FROM sessions s
       JOIN accounts a ON a.id = s.account_id
      WHERE s.token_hash = $1
        AND s.expires_at > NOW()
        AND a.status = 'active'`,
    [hashSessionToken(token)],
  );

  if (result.rowCount !== 1) {
    throw new ApiError(401, "SESSION_EXPIRED", "Phiên đăng nhập đã hết hạn.");
  }

  request.authAccount = result.rows[0];
  return result.rows[0];
}

async function isRealtimeSessionActive(account) {
  const result = await pool.query(
    `SELECT 1
       FROM sessions session
       JOIN accounts account ON account.id = session.account_id
      WHERE session.id = $1
        AND session.account_id = $2
        AND session.expires_at > NOW()
        AND account.status = 'active'`,
    [account.session_id, account.id],
  );
  return result.rowCount === 1;
}

async function authenticateBattleRealtime(request) {
  const hasTicket = typeof request.headers["x-battle-ticket"] === "string";
  if (hasTicket || config.battleRealtimeRequireTicket) {
    if (!battleMemoryWorkers) {
      throw new ApiError(
        503,
        "BATTLE_ROUTE_UNAVAILABLE",
        "Match worker realtime chưa được bật.",
      );
    }
    return authenticateBattleRealtimeTicket(
      request,
      battleMemoryWorkers.instanceId,
    );
  }
  return requireSession(request);
}

function requireRole(account, role) {
  if (account.role !== role) {
    throw new ApiError(403, "FORBIDDEN", "Tài khoản không có quyền thực hiện chức năng này.");
  }
}

async function createSession(client, accountId, role = "player") {
  const token = createSessionToken();
  const lifetimeHours = role === "admin"
    ? config.adminSessionHours
    : config.sessionDays * 24;
  await client.query(
    `INSERT INTO sessions (account_id, token_hash, expires_at)
     VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 hour'))`,
    [accountId, hashSessionToken(token), lifetimeHours],
  );
  return token;
}

async function sessionPayload(account, client = pool) {
  const profileResult = await client.query(
    `SELECT display_name, gender, level, experience, stamina, stamina_max, avatar_key
       FROM player_profiles
      WHERE account_id = $1`,
    [account.id],
  );

  const profile = profileResult.rows[0] ?? null;
  if (profile) {
    profile.experience_max = experienceMaxForLevel(profile.level);
  }

  return {
    account: { id: account.id, username: account.username, role: account.role },
    needs_character: profileResult.rowCount === 0,
    profile,
  };
}

async function register(request, response) {
  await consumeRateLimit(
    `login:${clientIp(request)}`,
    config.loginRateLimit,
    config.loginRateWindowSeconds,
  );
  const input = validateCredentials(await readJson(request));
  if (!input.ok) {
    throw new ApiError(400, "INVALID_CREDENTIALS", input.message);
  }

  const deviceId = normalizeDeviceId(request.headers["x-device-id"]);
  if (!deviceId) {
    throw new ApiError(
      400,
      "DEVICE_ID_REQUIRED",
      "Không xác định được mã cài đặt của máy.",
    );
  }

  const ip = clientIp(request);
  const passwordHash = await hashPassword(input.password);

  try {
    const result = await withTransaction(async (client) => {
      const policy = await checkRegistrationCooldown(client, ip, deviceId);
      if (!policy.allowed) {
        throw new ApiError(
          429,
          "REGISTRATION_COOLDOWN",
          cooldownMessage(policy.retryAfterSeconds, policy.reason),
          policy.retryAfterSeconds,
        );
      }
      const accountResult = await client.query(
        `INSERT INTO accounts (username, password_hash)
         VALUES ($1, $2)
         RETURNING id, username, role`,
        [input.username, passwordHash],
      );
      const account = accountResult.rows[0];
      await recordRegistration(client, account.id, policy);
      const token = await createSession(client, account.id, account.role);
      return { token, account };
    });

    sendJson(response, 201, {
      ok: true,
      token: result.token,
      account: result.account,
      needs_character: true,
      profile: null,
    });
  } catch (error) {
    if (error?.code === "23505") {
      throw new ApiError(409, "USERNAME_TAKEN", "Tên tài khoản đã được sử dụng.");
    }
    throw error;
  }
}

async function login(request, response) {
  await consumeRateLimit(
    `login:${clientIp(request)}`,
    config.loginRateLimit,
    config.loginRateWindowSeconds,
  );
  const input = validateLoginCredentials(await readJson(request));
  if (!input.ok) {
    throw new ApiError(400, "INVALID_CREDENTIALS", input.message);
  }
  await consumeRateLimit(
    `login-account:${input.username}`,
    config.loginAccountRateLimit,
    config.loginAccountRateWindowSeconds,
  );

  const accountResult = await pool.query(
    `SELECT id, username, role, password_hash
       FROM accounts
      WHERE LOWER(username) = $1
        AND status = 'active'`,
    [input.username],
  );

  const passwordHash = accountResult.rows[0]?.password_hash ?? dummyPasswordHash;
  const passwordMatches = await verifyPassword(input.password, passwordHash);
  if (accountResult.rowCount !== 1 || !passwordMatches) {
    throw new ApiError(401, "LOGIN_FAILED", "Tài khoản hoặc mật khẩu không đúng.");
  }

  const account = accountResult.rows[0];
  const token = await withTransaction(async (client) => {
    await client.query(
      "UPDATE accounts SET last_login_at = NOW() WHERE id = $1",
      [account.id],
    );
    await client.query(
      "DELETE FROM sessions WHERE account_id = $1 AND expires_at <= NOW()",
      [account.id],
    );
    return createSession(client, account.id, account.role);
  });

  sendJson(response, 200, {
    ok: true,
    token,
    ...(await sessionPayload(account)),
  });
}

async function getSession(request, response) {
  const account = await requireSession(request);
  sendJson(response, 200, { ok: true, ...(await sessionPayload(account)) });
}

async function logout(request, response) {
  const account = await requireSession(request);
  await removeAccountFromGameRoom(account.id);
  await leaveAdmission(account);
  await pool.query("DELETE FROM sessions WHERE id = $1", [account.session_id]);
  battleRealtime.revokeSession(account.session_id);
  sendJson(response, 200, { ok: true });
}

async function joinQueue(request, response) {
  const account = await requireSession(request);
  const profile = await pool.query(
    "SELECT 1 FROM player_profiles WHERE account_id = $1",
    [account.id],
  );
  if (profile.rowCount !== 1) {
    throw new ApiError(409, "CHARACTER_REQUIRED", "Tài khoản chưa tạo nhân vật.");
  }

  const admission = await joinAdmission(account);
  sendJson(response, 200, { ok: true, admission });
}

async function queueStatus(request, response) {
  const account = await requireSession(request);
  await consumeRateLimit(
    `queue:${account.id}`,
    config.queuePollRateLimit,
    60,
  );
  const admission = await getAdmissionStatus(account);
  sendJson(response, 200, { ok: true, admission });
}

async function heartbeat(request, response) {
  const account = await requireSession(request);
  await consumeRateLimit(`heartbeat:${account.id}`, 10, 60);
  if (!(await heartbeatAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_EXPIRED",
      "Suất online đã hết hạn. Hãy vào lại hàng chờ.",
    );
  }
  sendJson(response, 200, { ok: true });
}

async function leaveQueue(request, response) {
  const account = await requireSession(request);
  await removeAccountFromGameRoom(account.id);
  await leaveAdmission(account);
  sendJson(response, 200, { ok: true });
}

async function requireGameRoomAdmission(account) {
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Bạn phải đang ở trong game để sử dụng phòng PvP.",
    );
  }
}

async function getGameRooms(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-list:${account.id}`, 60, 60);
  const url = new URL(request.url, "http://localhost");
  const rooms = await listGameRooms(url.searchParams.get("tab") ?? "solo");
  sendJson(response, 200, { ok: true, rooms });
}

async function getCurrentGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-current:${account.id}`, 120, 60);
  const room = await currentGameRoom(account.id);
  sendJson(response, 200, { ok: true, room });
}

async function getGameMaps(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-maps:${account.id}`, 60, 60);
  sendJson(response, 200, { ok: true, maps: await listGameMaps() });
}

async function createPlayerGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 20, 60);
  const room = await createGameRoom(account.id, await readJson(request));
  sendJson(response, 201, { ok: true, room });
}

async function joinPlayerGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const body = await readJson(request);
  const room = await joinGameRoom(account.id, body?.room_code);
  sendJson(response, 200, { ok: true, room });
}

async function quickJoinPlayerGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const body = await readJson(request);
  const room = await quickJoinGameRoom(account.id, body?.tab_key);
  sendJson(response, 200, { ok: true, room });
}

async function leavePlayerGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const result = await leaveGameRoom(account.id);
  sendJson(response, 200, { ok: true, ...result });
}

async function selectPlayerGameRoomMap(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const body = await readJson(request);
  const room = await selectGameRoomMap(account.id, body?.map_key);
  sendJson(response, 200, { ok: true, room });
}

async function startPlayerGameRoom(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const room = await startGameRoom(account.id);
  sendJson(response, 200, { ok: true, room });
}

async function cancelPlayerGameRoomMatchmaking(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`rooms-write:${account.id}`, 30, 60);
  const room = await cancelGameRoomMatchmaking(account.id);
  sendJson(response, 200, { ok: true, room });
}

async function getCurrentGameMatch(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-current:${account.id}`, 180, 60);
  const match = await currentGameMatch(account.id);
  sendJson(response, 200, { ok: true, match });
}

async function getPlayerGameMatchTeamChat(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-chat-read:${account.id}`, 120, 60);
  const url = new URL(request.url, "http://localhost");
  const channel = url.searchParams.get("channel") === "battle" ? "battle" : "team";
  const payload = channel === "battle"
    ? await listGameMatchBattleMessages(
      account.id,
      url.searchParams.get("after_id") ?? "0",
      url.searchParams.get("limit") ?? "50",
    )
    : await listGameMatchTeamMessages(
      account.id,
      url.searchParams.get("after_id") ?? "0",
      url.searchParams.get("limit") ?? "50",
    );
  sendJson(response, 200, { ok: true, ...payload });
}

async function sendPlayerGameMatchTeamChat(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-chat-send:${account.id}`, 8, 10);
  const body = await readJson(request);
  const input = validateChatMessage(body, BATTLE_CHAT_MESSAGE_MAX_LENGTH);
  if (!input.ok) {
    throw new ApiError(400, "INVALID_CHAT_MESSAGE", input.message);
  }
  const channel = body?.channel === "battle" ? "battle" : "team";
  const message = channel === "battle"
    ? await sendGameMatchBattleMessage(account.id, input.message)
    : await sendGameMatchTeamMessage(account.id, input.message);
  sendJson(response, 201, {
    ok: true,
    channel,
    message,
  });
}

async function confirmPlayerGameMatch(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-write:${account.id}`, 60, 60);
  const match = await confirmGameMatch(account.id);
  sendJson(response, 200, { ok: true, match });
}

async function selectPlayerGameMatchTank(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-write:${account.id}`, 60, 60);
  const body = await readJson(request);
  const match = await selectGameMatchTank(account.id, body?.tank_key);
  sendJson(response, 200, { ok: true, match });
}

async function equipPlayerGameMatchSkin(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-write:${account.id}`, 60, 60);
  const body = await readJson(request);
  const match = await equipGameMatchSkin(
    account.id,
    body?.tank_key,
    body?.skin_key,
  );
  sendJson(response, 200, { ok: true, match });
}

async function deployPlayerGameMatchTank(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-write:${account.id}`, 60, 60);
  const match = await deployGameMatchTank(account.id);
  sendJson(response, 200, { ok: true, match });
}

async function reportPlayerGameMatchLoad(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`match-load:${account.id}`, 180, 60);
  const body = await readJson(request);
  const match = await reportGameMatchLoad(account.id, body?.progress);
  sendJson(response, 200, { ok: true, match });
}

async function getPlayerBattleSnapshot(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`battle-snapshot:${account.id}`, 900, 60);
  const snapshot = await battleService.getSnapshot(account.id);
  sendJson(response, 200, { ok: true, snapshot });
}

async function submitPlayerBattleCommand(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`battle-command:${account.id}`, 900, 60);
  const command = await battleService.submitCommand(
    account.id,
    await readJson(request),
  );
  sendJson(response, 200, { ok: true, ...command });
}

async function createPlayerBattleRealtimeTicket(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`battle-ticket:${account.id}`, 30, 60);
  if (!battleMemoryWorkers) {
    throw new ApiError(
      503,
      "BATTLE_ROUTE_UNAVAILABLE",
      "Match worker realtime chưa được bật.",
    );
  }
  const ticket = await issueBattleRealtimeTicket(
    account,
    battleMemoryWorkers,
    {
      lifetimeSeconds: config.battleRealtimeTicketSeconds,
      localPublicRealtimeUrl: config.battlePublicRealtimeUrl,
    },
  );
  sendJson(response, 201, { ok: true, ...ticket });
}

async function createCharacter(request, response) {
  const body = await readJson(request);

  try {
    const payload = await withTransaction(async (client) => {
      const account = await requireSession(request, client);
      const input = validateCharacter(body, {
        allowAdminName: account.role === "admin",
      });
      if (!input.ok) {
        throw new ApiError(400, "INVALID_CHARACTER", input.message);
      }

      const existing = await client.query(
        "SELECT 1 FROM player_profiles WHERE account_id = $1 FOR UPDATE",
        [account.id],
      );
      if (existing.rowCount > 0) {
        throw new ApiError(409, "CHARACTER_EXISTS", "Tài khoản đã có nhân vật.");
      }

      const avatarKey =
        input.gender === "male" ? "default_male" : "default_female";
      await client.query(
        `INSERT INTO player_profiles
           (account_id, display_name, gender, avatar_key)
         VALUES ($1, $2, $3, $4)`,
        [account.id, input.displayName, input.gender, avatarKey],
      );
      await client.query(
        `INSERT INTO player_currencies (account_id, xu, locked_xu, silver)
         VALUES ($1, $2, $3, $4)`,
        [
          account.id,
          STARTER_CURRENCY_BALANCE.xu,
          STARTER_CURRENCY_BALANCE.lockedXu,
          STARTER_CURRENCY_BALANCE.silver,
        ],
      );
      await client.query(
        `INSERT INTO player_rewards (account_id, reward_key, status)
         VALUES ($1, 'newcomer_iron_man', 'pending')`,
        [account.id],
      );

      return sessionPayload(account, client);
    });

    sendJson(response, 201, { ok: true, ...payload });
  } catch (error) {
    if (error?.code === "23505") {
      throw new ApiError(
        409,
        "DISPLAY_NAME_TAKEN",
        "Tên nhân vật đã có người sử dụng.",
      );
    }
    throw error;
  }
}

async function loadLobbyData(accountId, client = pool) {
  const result = await client.query(
    `SELECT p.display_name, p.gender, p.level, p.experience,
            p.stamina, p.stamina_max, p.avatar_key,
            c.xu, c.locked_xu, c.silver,
            t.tank_key, t.display_name AS tank_name,
            t.max_level AS tank_max_level,
            t.damage_type AS tank_damage_type,
            t.role_key AS tank_role_key,
            t.quality_key AS tank_quality_key,
            t.difficulty AS tank_difficulty,
            t.avatar_asset_key AS tank_avatar_asset_key,
            t.preview_asset_key AS tank_preview_asset_key,
            t.thumbnail_asset_key AS tank_thumbnail_asset_key,
            equipped_skin.skin_key AS equipped_skin_key,
            equipped_skin.quality_key AS equipped_skin_quality,
            pt.level AS tank_level, pt.experience AS tank_experience,
            tls.hit_points, tls.basic_attack_damage,
            tls.penetration, tls.physical_armor, tls.energy_shield,
            tls.move_speed, tls.fire_rate, tls.attack_range,
            (tls.critical_chance_basis_points::numeric / 100)::float8
                AS critical_chance_percent,
            (tls.critical_damage_basis_points::numeric / 100)::float8
                AS critical_damage_percent
       FROM player_profiles p
       JOIN player_currencies c ON c.account_id = p.account_id
       LEFT JOIN player_tanks pt
              ON pt.account_id = p.account_id AND pt.is_primary
       LEFT JOIN tanks t ON t.id = pt.tank_id
       LEFT JOIN tank_skins equipped_skin
              ON equipped_skin.id = pt.equipped_skin_id
       LEFT JOIN tank_level_stats tls
              ON tls.tank_id = pt.tank_id AND tls.level = pt.level
      WHERE p.account_id = $1`,
    [accountId],
  );

  if (result.rowCount !== 1) {
    throw new ApiError(409, "CHARACTER_REQUIRED", "Tài khoản chưa tạo nhân vật.");
  }

  const ownedTanks = await client.query(
    `SELECT t.tank_key, t.display_name AS tank_name,
            t.max_level AS tank_max_level,
            t.damage_type AS tank_damage_type,
            t.role_key AS tank_role_key,
            t.quality_key AS tank_quality_key,
            t.difficulty AS tank_difficulty,
            t.avatar_asset_key AS tank_avatar_asset_key,
            t.preview_asset_key AS tank_preview_asset_key,
            t.thumbnail_asset_key AS tank_thumbnail_asset_key,
            pt.level AS tank_level, pt.experience AS tank_experience,
            pt.is_primary,
            equipped_skin.skin_key AS equipped_skin_key,
            equipped_skin.quality_key AS equipped_skin_quality,
            tls.hit_points, tls.basic_attack_damage,
            tls.penetration, tls.physical_armor, tls.energy_shield,
            tls.move_speed, tls.fire_rate, tls.attack_range,
            (tls.critical_chance_basis_points::numeric / 100)::float8
                AS critical_chance_percent,
            (tls.critical_damage_basis_points::numeric / 100)::float8
                AS critical_damage_percent,
            COALESCE(
              (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'skill_key', ts.skill_key,
                    'slot_index', ts.slot_index,
                    'display_name', ts.display_name,
                    'icon_asset_key', ts.icon_asset_key,
                    'base_damage', ts.base_damage,
                    'damage_per_tank_level', ts.damage_per_tank_level,
                    'cooldown_ms', ts.cooldown_ms,
                    'description', ts.description
                  )
                  ORDER BY ts.slot_index
                )
                FROM tank_skills ts
                WHERE ts.tank_id = t.id
              ),
              '[]'::jsonb
            ) AS skills,
            COALESCE(
              (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'skin_key', skin.skin_key,
                    'display_name', skin.display_name,
                    'quality_key', skin.quality_key,
                    'avatar_asset_key', skin.avatar_asset_key,
                    'preview_asset_key', skin.preview_asset_key,
                    'stat_modifiers', skin.stat_modifiers,
                    'is_default', skin.is_default,
                    'is_equipped', skin.id = pt.equipped_skin_id,
                    'owned', EXISTS (
                      SELECT 1
                      FROM player_tank_skins owned_skin
                      WHERE owned_skin.account_id = pt.account_id
                        AND owned_skin.tank_skin_id = skin.id
                    )
                  )
                  ORDER BY skin.is_default DESC, skin.skin_key
                )
                FROM tank_skins skin
                WHERE skin.tank_id = t.id AND skin.enabled
              ),
              '[]'::jsonb
            ) AS skins,
            COALESCE(
              (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'source_key', bonus.source_key,
                    'hit_points', bonus.hit_points,
                    'basic_attack_damage', bonus.basic_attack_damage,
                    'penetration', bonus.penetration,
                    'physical_armor', bonus.physical_armor,
                    'energy_shield', bonus.energy_shield
                  )
                  ORDER BY bonus.source_key
                )
                FROM player_tank_stat_bonuses bonus
                WHERE bonus.account_id = pt.account_id
                  AND bonus.tank_id = pt.tank_id
              ),
              '[]'::jsonb
            ) AS stat_bonus_sources
       FROM player_tanks pt
       JOIN tanks t ON t.id = pt.tank_id
       LEFT JOIN tank_skins equipped_skin
              ON equipped_skin.id = pt.equipped_skin_id
       LEFT JOIN tank_level_stats tls
              ON tls.tank_id = pt.tank_id AND tls.level = pt.level
      WHERE pt.account_id = $1
      ORDER BY pt.is_primary DESC, t.tank_key`,
    [accountId],
  );

  const skinCollectionRules = await client.query(
    `SELECT rule_key, requirement_type, required_quality,
            required_distinct_quality_count, requires_sss,
            hit_points_percent, attack_percent, frame_tier,
            revive_speed_percent, revive_duration_seconds
       FROM tank_skin_collection_rules
      WHERE enabled
      ORDER BY sort_order, id`,
  );
  const militaryRank = buildMilitaryRankSummary(ownedTanks.rows);
  const militaryRankSource = militaryRankBonusSource(militaryRank);
  for (const tank of ownedTanks.rows) {
    const existingSources = Array.isArray(tank.stat_bonus_sources)
      ? tank.stat_bonus_sources
      : [];
    tank.stat_bonus_sources = [
      ...existingSources.filter(
        (source) => source?.source_key !== "military_rank",
      ),
      militaryRankSource,
    ];
    applyTankSkinCollectionBonus(tank, skinCollectionRules.rows);
    tank.skills = applyMilitaryRankCooldowns(
      tank.skills,
      militaryRank.cooldown_reduction_percent,
    );
    tank.military_rank_cooldown_reduction_percent =
      militaryRank.cooldown_reduction_percent;
  }

  const lobby = result.rows[0];
  lobby.experience_max = experienceMaxForLevel(lobby.level);
  lobby.owned_tanks = ownedTanks.rows;
  lobby.military_rank = militaryRank;
  const primaryTank = ownedTanks.rows.find((tank) => tank.is_primary);
  if (primaryTank) {
    lobby.base_stats = primaryTank.base_stats;
    lobby.stat_bonus_sources = primaryTank.stat_bonus_sources;
    lobby.stat_bonuses = primaryTank.stat_bonuses;
    lobby.effective_stats = primaryTank.effective_stats;
    lobby.skin_collection_bonus = primaryTank.skin_collection_bonus;
    for (const statKey of [
      "hit_points",
      "basic_attack_damage",
      "penetration",
      "physical_armor",
      "energy_shield",
      "move_speed",
      "fire_rate",
      "attack_range",
      "critical_chance_percent",
      "critical_damage_percent",
    ]) {
      lobby[`base_${statKey}`] = primaryTank[`base_${statKey}`];
      lobby[statKey] = primaryTank[statKey];
    }
  }
  const pendingReward = await client.query(
    `SELECT reward.reward_key,
            tank.tank_key,
            tank.display_name AS tank_name,
            tank.max_level AS tank_max_level,
            tank.damage_type AS tank_damage_type,
            tank.avatar_asset_key AS tank_avatar_asset_key,
            tank.preview_asset_key AS tank_preview_asset_key,
            tank.thumbnail_asset_key AS tank_thumbnail_asset_key,
            COALESCE(
              (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'skill_key', skill.skill_key,
                    'slot_index', skill.slot_index,
                    'display_name', skill.display_name,
                    'icon_asset_key', skill.icon_asset_key,
                    'base_damage', skill.base_damage,
                    'damage_per_tank_level', skill.damage_per_tank_level,
                    'cooldown_ms', skill.cooldown_ms,
                    'description', skill.description
                  )
                  ORDER BY skill.slot_index
                )
                FROM tank_skills skill
                WHERE skill.tank_id = tank.id
              ),
              '[]'::jsonb
            ) AS skills
       FROM player_rewards reward
       JOIN tanks tank ON tank.tank_key = 'gangtiexia03' AND tank.enabled
      WHERE reward.account_id = $1
        AND reward.reward_key = 'newcomer_iron_man'
        AND reward.status = 'pending'`,
    [accountId],
  );
  lobby.pending_tank_reward =
    pendingReward.rowCount === 1 ? pendingReward.rows[0] : null;
  return lobby;
}

async function getLobby(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Máy chủ đang giới hạn người chơi. Hãy vào hàng chờ trước.",
    );
  }
  const lobby = await loadLobbyData(account.id);
  sendJson(response, 200, { ok: true, lobby });
}

async function getShopCatalog(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  const catalog = await withReadTransaction((client) =>
    loadShopCatalog(client, account.id)
  );
  sendJson(response, 200, { ok: true, catalog });
}

async function getPlayerInventory(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  const inventory = await withReadTransaction((client) =>
    loadInventory(client, account.id)
  );
  sendJson(response, 200, { ok: true, inventory });
}

async function purchaseShopOffer(request, response) {
  const account = await requireSession(request);
  await requireGameRoomAdmission(account);
  await consumeRateLimit(`purchase:${account.id}`, 20, 60);
  const input = validatePurchaseRequest(
    await readJson(request),
    request.headers["idempotency-key"],
  );
  const purchase = await withTransaction((client) =>
    purchaseOffer(client, account.id, input)
  );
  sendJson(response, 200, { ok: true, purchase });
}

async function setPrimaryTank(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Máy chủ đang giới hạn người chơi. Hãy vào hàng chờ trước.",
    );
  }

  const body = await readJson(request);
  const tankKey = typeof body?.tank_key === "string"
    ? body.tank_key.trim()
    : "";
  if (!/^[a-z0-9_]{1,64}$/.test(tankKey)) {
    throw new ApiError(400, "INVALID_TANK", "Tank được chọn không hợp lệ.");
  }

  const lobby = await withTransaction(async (client) => {
    await client.query(
      "SELECT pg_advisory_xact_lock($1::bigint)",
      [account.id],
    );
    const owned = await client.query(
      `SELECT pt.id
         FROM player_tanks pt
         JOIN tanks t ON t.id = pt.tank_id
        WHERE pt.account_id = $1
          AND t.tank_key = $2
          AND t.enabled
        FOR UPDATE OF pt`,
      [account.id, tankKey],
    );
    if (owned.rowCount !== 1) {
      throw new ApiError(
        409,
        "TANK_NOT_OWNED",
        "Bạn chưa sở hữu Tank này.",
      );
    }

    await client.query(
      "UPDATE player_tanks SET is_primary = FALSE WHERE account_id = $1 AND is_primary",
      [account.id],
    );
    await client.query(
      "UPDATE player_tanks SET is_primary = TRUE WHERE id = $1",
      [owned.rows[0].id],
    );
    return loadLobbyData(account.id, client);
  });

  sendJson(response, 200, { ok: true, lobby });
}

async function equipTankSkin(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Bạn phải đang ở trong game để sử dụng Skin Tank.",
    );
  }

  const body = await readJson(request);
  const tankKey = typeof body?.tank_key === "string"
    ? body.tank_key.trim()
    : "";
  const skinKey = typeof body?.skin_key === "string"
    ? body.skin_key.trim()
    : "";
  if (!/^[a-z0-9_]{1,64}$/.test(tankKey)) {
    throw new ApiError(400, "INVALID_TANK", "Tank được chọn không hợp lệ.");
  }
  if (!/^[a-z0-9_]{1,64}$/.test(skinKey)) {
    throw new ApiError(400, "INVALID_SKIN", "Skin được chọn không hợp lệ.");
  }

  const lobby = await withTransaction(async (client) => {
    await client.query(
      "SELECT pg_advisory_xact_lock($1::bigint)",
      [account.id],
    );
    const owned = await client.query(
      `SELECT pt.id AS player_tank_id, skin.id AS tank_skin_id
         FROM player_tanks pt
         JOIN tanks tank ON tank.id = pt.tank_id
         JOIN tank_skins skin
           ON skin.tank_id = tank.id
          AND skin.skin_key = $3
          AND skin.enabled
         JOIN player_tank_skins owned_skin
           ON owned_skin.account_id = pt.account_id
          AND owned_skin.tank_skin_id = skin.id
        WHERE pt.account_id = $1
          AND tank.tank_key = $2
          AND tank.enabled
        FOR UPDATE OF pt, owned_skin`,
      [account.id, tankKey, skinKey],
    );
    if (owned.rowCount !== 1) {
      throw new ApiError(
        409,
        "SKIN_NOT_OWNED",
        "Bạn chưa sở hữu Skin này.",
      );
    }

    await client.query(
      `UPDATE player_tanks
          SET equipped_skin_id = $1
        WHERE id = $2`,
      [owned.rows[0].tank_skin_id, owned.rows[0].player_tank_id],
    );
    return loadLobbyData(account.id, client);
  });

  sendJson(response, 200, { ok: true, lobby });
}

async function claimNewcomerTank(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Bạn phải đang ở trong game để nhận Tank tân thủ.",
    );
  }

  const result = await withTransaction(async (client) => {
    await client.query(
      "SELECT pg_advisory_xact_lock($1::bigint)",
      [account.id],
    );
    const reward = await client.query(
      `SELECT status
         FROM player_rewards
        WHERE account_id = $1
          AND reward_key = 'newcomer_iron_man'
        FOR UPDATE`,
      [account.id],
    );
    if (reward.rowCount !== 1) {
      throw new ApiError(
        409,
        "REWARD_NOT_AVAILABLE",
        "Tài khoản này không có quà Tank tân thủ.",
      );
    }

    if (reward.rows[0].status === "claimed") {
      return {
        alreadyClaimed: true,
        lobby: await loadLobbyData(account.id, client),
      };
    }

    const granted = await client.query(
      `INSERT INTO player_tanks
         (account_id, tank_id, level, experience, is_primary)
       SELECT
         $1,
         tank.id,
         1,
         0,
         NOT EXISTS (
           SELECT 1
             FROM player_tanks current_primary
            WHERE current_primary.account_id = $1
              AND current_primary.is_primary
         )
         FROM tanks tank
        WHERE tank.tank_key = 'gangtiexia03'
          AND tank.enabled
       ON CONFLICT (account_id, tank_id) DO NOTHING
       RETURNING id`,
      [account.id],
    );
    if (granted.rowCount !== 1) {
      const alreadyOwned = await client.query(
        `SELECT 1
           FROM player_tanks owned
           JOIN tanks tank ON tank.id = owned.tank_id
          WHERE owned.account_id = $1
            AND tank.tank_key = 'gangtiexia03'`,
        [account.id],
      );
      if (alreadyOwned.rowCount !== 1) {
        throw new ApiError(
          500,
          "TANK_CATALOG_MISSING",
          "Dữ liệu Tank Iron Man chưa sẵn sàng.",
        );
      }
    }

    await client.query(
      `INSERT INTO player_tank_skins (account_id, tank_skin_id)
       SELECT $1, skin.id
         FROM tank_skins skin
         JOIN tanks tank ON tank.id = skin.tank_id
        WHERE tank.tank_key = 'gangtiexia03'
          AND skin.is_default
          AND skin.enabled
       ON CONFLICT (account_id, tank_skin_id) DO NOTHING`,
      [account.id],
    );
    await client.query(
      `UPDATE player_tanks player_tank
          SET equipped_skin_id = skin.id
         FROM tanks tank
         JOIN tank_skins skin
           ON skin.tank_id = tank.id
          AND skin.is_default
          AND skin.enabled
        WHERE player_tank.account_id = $1
          AND player_tank.tank_id = tank.id
          AND tank.tank_key = 'gangtiexia03'
          AND player_tank.equipped_skin_id IS NULL`,
      [account.id],
    );
    const claimed = await client.query(
      `UPDATE player_rewards
          SET status = 'claimed',
              claimed_at = NOW()
        WHERE account_id = $1
          AND reward_key = 'newcomer_iron_man'
          AND status = 'pending'`,
      [account.id],
    );
    if (claimed.rowCount !== 1) {
      throw new ApiError(
        409,
        "REWARD_ALREADY_CLAIMED",
        "Quà Tank tân thủ đã được nhận.",
      );
    }

    return {
      alreadyClaimed: false,
      lobby: await loadLobbyData(account.id, client),
    };
  });

  sendJson(response, 200, {
    ok: true,
    already_claimed: result.alreadyClaimed,
    lobby: result.lobby,
  });
}

async function requireChatAdmission(account) {
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Bạn phải đang ở trong game để sử dụng chat.",
    );
  }
}

async function getWorldChatMessages(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  await consumeRateLimit(`chat-read:${account.id}`, 40, 60);

  const url = new URL(request.url, "http://localhost");
  const requestedAfterId = String(url.searchParams.get("after_id") ?? "0");
  const afterId = /^\d+$/.test(requestedAfterId) ? requestedAfterId : "0";
  const requestedLimit = Number.parseInt(url.searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(50, Math.max(1, requestedLimit))
    : 50;

  // Keep rows for moderation, but optionally expose only this server session.
  const visibleSince = config.worldChatResetOnServerStart
    ? new Date(serverStartedAt)
    : new Date(0);
  const result = await pool.query(
    `SELECT recent.id, recent.sender_name, recent.body, recent.created_at
       FROM (
         SELECT m.id, p.display_name AS sender_name, m.body, m.created_at
           FROM chat_messages m
           JOIN player_profiles p ON p.account_id = m.sender_account_id
          WHERE m.id > $1::bigint
            AND m.created_at >= $3::timestamptz
          ORDER BY m.id DESC
          LIMIT $2
       ) recent
      ORDER BY recent.id`,
    [afterId, limit, visibleSince],
  );

  sendJson(response, 200, {
    ok: true,
    channel: "world",
    server_started_at: new Date(serverStartedAt).toISOString(),
    messages: result.rows,
  });
}

async function sendWorldChatMessage(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  await consumeRateLimit(`chat-send:${account.id}`, 8, 10);

  const input = validateChatMessage(await readJson(request));
  if (!input.ok) {
    throw new ApiError(400, "INVALID_CHAT_MESSAGE", input.message);
  }

  const result = await pool.query(
    `WITH sender AS (
       SELECT display_name
         FROM player_profiles
        WHERE account_id = $1
     ), inserted AS (
       INSERT INTO chat_messages (sender_account_id, body)
       SELECT $1, $2 FROM sender
       RETURNING id, body, created_at
     )
     SELECT inserted.id, sender.display_name AS sender_name,
            inserted.body, inserted.created_at
       FROM inserted CROSS JOIN sender`,
    [account.id, input.message],
  );

  if (result.rowCount !== 1) {
    throw new ApiError(409, "CHARACTER_REQUIRED", "Tài khoản chưa tạo nhân vật.");
  }

  sendJson(response, 201, {
    ok: true,
    channel: "world",
    message: result.rows[0],
  });
}

async function getSocialPlayers(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Máy chủ đang giới hạn người chơi. Hãy vào hàng chờ trước.",
    );
  }

  const url = new URL(request.url, "http://localhost");
  const tab = String(url.searchParams.get("tab") ?? "guild").trim();
  if (!["guild", "friends", "room"].includes(tab)) {
    throw new ApiError(400, "INVALID_SOCIAL_TAB", "Danh sách người chơi không hợp lệ.");
  }

  const result = await pool.query(
    `WITH viewer_guild AS (
       SELECT guild_id
         FROM guild_members
        WHERE account_id = $1
     ), accepted_friends AS (
       SELECT CASE
                WHEN account_id_low = $1 THEN account_id_high
                ELSE account_id_low
              END AS friend_account_id
         FROM player_friendships
        WHERE status = 'accepted'
          AND $1 IN (account_id_low, account_id_high)
     )
     SELECT profile.account_id::text,
            profile.display_name,
            profile.gender,
            profile.level,
            profile.avatar_key,
            COALESCE(guild.name, '') AS guild_name,
            (presence.account_id IS NOT NULL) AS online,
            (profile.account_id = $1) AS is_self,
            COALESCE(tank.tank_key, '') AS tank_key,
            COALESCE(tank.display_name, 'Tank') AS tank_name,
            COALESCE(player_tank.level, 1)::int AS tank_level
       FROM player_profiles profile
       LEFT JOIN online_presence presence
              ON presence.account_id = profile.account_id
             AND presence.lease_expires_at > NOW()
       LEFT JOIN guild_members guild_member
              ON guild_member.account_id = profile.account_id
       LEFT JOIN guilds guild ON guild.id = guild_member.guild_id
       LEFT JOIN player_tanks player_tank
              ON player_tank.account_id = profile.account_id
             AND player_tank.is_primary
       LEFT JOIN tanks tank ON tank.id = player_tank.tank_id
      WHERE (
              $2 = 'room'
              AND presence.account_id IS NOT NULL
            )
         OR (
              $2 = 'friends'
              AND profile.account_id IN (
                SELECT friend_account_id FROM accepted_friends
              )
            )
         OR (
              $2 = 'guild'
              AND (
                profile.account_id = $1
                OR guild_member.guild_id IN (
                  SELECT guild_id FROM viewer_guild
                )
              )
            )
      ORDER BY CASE WHEN profile.account_id = $1 THEN 0 ELSE 1 END,
               (presence.account_id IS NOT NULL) DESC,
               LOWER(profile.display_name),
               profile.account_id`,
    [account.id, tab],
  );

  sendJson(response, 200, {
    ok: true,
    tab,
    players: result.rows,
  });
}

function validateSocialTargetAccountId(value, ownAccountId) {
  const accountId = String(value ?? "").trim();
  if (!/^[1-9]\d{0,18}$/.test(accountId)) {
    throw new ApiError(400, "INVALID_PLAYER", "Người chơi không hợp lệ.");
  }
  if (accountId === String(ownAccountId)) {
    throw new ApiError(
      400,
      "CANNOT_TARGET_SELF",
      "Không thể thực hiện thao tác này với chính mình.",
    );
  }
  return accountId;
}

async function getFriends(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Máy chủ đang giới hạn người chơi. Hãy vào hàng chờ trước.",
    );
  }

  const url = new URL(request.url, "http://localhost");
  const view = String(url.searchParams.get("view") ?? "friends").trim();
  if (!["friends", "blocked", "requests", "search"].includes(view)) {
    throw new ApiError(400, "INVALID_FRIEND_VIEW", "Danh sách bạn bè không hợp lệ.");
  }
  const search = String(url.searchParams.get("q") ?? "").trim().slice(0, 32);

  const result = await pool.query(
    `SELECT profile.account_id::text,
            profile.display_name,
            profile.gender,
            profile.level,
            profile.avatar_key,
            COALESCE(guild.name, '') AS guild_name,
            (presence.account_id IS NOT NULL) AS online,
            COALESCE(tank.tank_key, '') AS tank_key,
            COALESCE(tank.display_name, 'Tank') AS tank_name,
            COALESCE(player_tank.level, 1)::int AS tank_level,
            friendship.status AS relationship_status,
            (
              friendship.status = 'pending'
              AND friendship.requested_by = profile.account_id
            ) AS incoming_request,
            (
              friendship.status = 'pending'
              AND friendship.requested_by = $1
            ) AS outgoing_request,
            (blocked_by_me.blocked_account_id IS NOT NULL) AS blocked_by_me,
            (blocked_me.blocker_account_id IS NOT NULL) AS blocked_me
       FROM player_profiles profile
       LEFT JOIN online_presence presence
              ON presence.account_id = profile.account_id
             AND presence.lease_expires_at > NOW()
       LEFT JOIN guild_members guild_member
              ON guild_member.account_id = profile.account_id
       LEFT JOIN guilds guild ON guild.id = guild_member.guild_id
       LEFT JOIN player_tanks player_tank
              ON player_tank.account_id = profile.account_id
             AND player_tank.is_primary
       LEFT JOIN tanks tank ON tank.id = player_tank.tank_id
       LEFT JOIN player_friendships friendship
              ON friendship.account_id_low = LEAST($1::bigint, profile.account_id)
             AND friendship.account_id_high = GREATEST($1::bigint, profile.account_id)
       LEFT JOIN player_blocks blocked_by_me
              ON blocked_by_me.blocker_account_id = $1
             AND blocked_by_me.blocked_account_id = profile.account_id
       LEFT JOIN player_blocks blocked_me
              ON blocked_me.blocker_account_id = profile.account_id
             AND blocked_me.blocked_account_id = $1
      WHERE profile.account_id <> $1
        AND (
          ($2 = 'friends' AND friendship.status = 'accepted')
          OR ($2 = 'blocked' AND blocked_by_me.blocked_account_id IS NOT NULL)
          OR ($2 = 'requests' AND friendship.status = 'pending')
          OR (
            $2 = 'search'
            AND $3 <> ''
            AND profile.display_name ILIKE ('%' || $3 || '%')
          )
        )
      ORDER BY
        CASE
          WHEN $2 = 'requests'
           AND friendship.status = 'pending'
           AND friendship.requested_by = profile.account_id
          THEN 0
          ELSE 1
        END,
        (presence.account_id IS NOT NULL) DESC,
        LOWER(profile.display_name),
        profile.account_id
      LIMIT 60`,
    [account.id, view, search],
  );

  sendJson(response, 200, {
    ok: true,
    view,
    query: search,
    players: result.rows,
  });
}

async function sendFriendRequest(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  await consumeRateLimit(`friend-request:${account.id}`, 12, 60);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );

  const outcome = await withTransaction(async (client) => {
    const targetResult = await client.query(
      `SELECT account_id
         FROM player_profiles
        WHERE account_id = $1`,
      [targetAccountId],
    );
    if (targetResult.rowCount !== 1) {
      throw new ApiError(404, "PLAYER_NOT_FOUND", "Không tìm thấy người chơi.");
    }

    const blockResult = await client.query(
      `SELECT 1
         FROM player_blocks
        WHERE (blocker_account_id = $1 AND blocked_account_id = $2)
           OR (blocker_account_id = $2 AND blocked_account_id = $1)
        LIMIT 1`,
      [account.id, targetAccountId],
    );
    if (blockResult.rowCount > 0) {
      throw new ApiError(
        409,
        "PLAYER_BLOCKED",
        "Không thể kết bạn khi một trong hai người đang chặn người kia.",
      );
    }

    const friendshipResult = await client.query(
      `SELECT status, requested_by::text
         FROM player_friendships
        WHERE account_id_low = LEAST($1::bigint, $2::bigint)
          AND account_id_high = GREATEST($1::bigint, $2::bigint)
        FOR UPDATE`,
      [account.id, targetAccountId],
    );
    if (friendshipResult.rowCount > 0) {
      const friendship = friendshipResult.rows[0];
      if (friendship.status === "accepted") {
        throw new ApiError(409, "ALREADY_FRIENDS", "Hai người đã là bạn bè.");
      }
      if (
        friendship.status === "pending"
        && friendship.requested_by === targetAccountId
      ) {
        await client.query(
          `UPDATE player_friendships
              SET status = 'accepted', updated_at = NOW()
            WHERE account_id_low = LEAST($1::bigint, $2::bigint)
              AND account_id_high = GREATEST($1::bigint, $2::bigint)`,
          [account.id, targetAccountId],
        );
        return "accepted";
      }
      throw new ApiError(
        409,
        "REQUEST_ALREADY_SENT",
        "Lời mời kết bạn đã được gửi trước đó.",
      );
    }

    await client.query(
      `INSERT INTO player_friendships (
         account_id_low,
         account_id_high,
         requested_by,
         status
       )
       VALUES (
         LEAST($1::bigint, $2::bigint),
         GREATEST($1::bigint, $2::bigint),
         $1,
         'pending'
       )`,
      [account.id, targetAccountId],
    );
    return "pending";
  });

  sendJson(response, 201, {
    ok: true,
    account_id: targetAccountId,
    relationship_status: outcome,
  });
}

async function acceptFriendRequest(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );
  const result = await pool.query(
    `UPDATE player_friendships
        SET status = 'accepted', updated_at = NOW()
      WHERE account_id_low = LEAST($1::bigint, $2::bigint)
        AND account_id_high = GREATEST($1::bigint, $2::bigint)
        AND status = 'pending'
        AND requested_by = $2
      RETURNING account_id_low`,
    [account.id, targetAccountId],
  );
  if (result.rowCount !== 1) {
    throw new ApiError(409, "REQUEST_NOT_FOUND", "Lời mời kết bạn không còn tồn tại.");
  }
  sendJson(response, 200, { ok: true, account_id: targetAccountId });
}

async function declineFriendRequest(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );
  await pool.query(
    `DELETE FROM player_friendships
      WHERE account_id_low = LEAST($1::bigint, $2::bigint)
        AND account_id_high = GREATEST($1::bigint, $2::bigint)
        AND status = 'pending'`,
    [account.id, targetAccountId],
  );
  sendJson(response, 200, { ok: true, account_id: targetAccountId });
}

async function removeFriend(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );
  await pool.query(
    `DELETE FROM player_friendships
      WHERE account_id_low = LEAST($1::bigint, $2::bigint)
        AND account_id_high = GREATEST($1::bigint, $2::bigint)
        AND status = 'accepted'`,
    [account.id, targetAccountId],
  );
  sendJson(response, 200, { ok: true, account_id: targetAccountId });
}

async function blockPlayer(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );

  await withTransaction(async (client) => {
    const targetResult = await client.query(
      `SELECT account_id FROM player_profiles WHERE account_id = $1`,
      [targetAccountId],
    );
    if (targetResult.rowCount !== 1) {
      throw new ApiError(404, "PLAYER_NOT_FOUND", "Không tìm thấy người chơi.");
    }
    await client.query(
      `INSERT INTO player_blocks (blocker_account_id, blocked_account_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [account.id, targetAccountId],
    );
    await client.query(
      `DELETE FROM player_friendships
        WHERE account_id_low = LEAST($1::bigint, $2::bigint)
          AND account_id_high = GREATEST($1::bigint, $2::bigint)`,
      [account.id, targetAccountId],
    );
  });

  sendJson(response, 200, { ok: true, account_id: targetAccountId });
}

async function unblockPlayer(request, response) {
  const account = await requireSession(request);
  await requireChatAdmission(account);
  const body = await readJson(request);
  const targetAccountId = validateSocialTargetAccountId(
    body?.account_id,
    account.id,
  );
  await pool.query(
    `DELETE FROM player_blocks
      WHERE blocker_account_id = $1
        AND blocked_account_id = $2`,
    [account.id, targetAccountId],
  );
  sendJson(response, 200, { ok: true, account_id: targetAccountId });
}

async function inviteSocialPlayerToRoom(request, response) {
  const account = await requireSession(request);
  if (!(await hasAdmission(account))) {
    throw new ApiError(
      409,
      "ADMISSION_REQUIRED",
      "Máy chủ đang giới hạn người chơi. Hãy vào hàng chờ trước.",
    );
  }
  const body = await readJson(request);
  const inviteeAccountId = String(body?.account_id ?? "").trim();
  if (!/^[1-9]\d{0,18}$/.test(inviteeAccountId)) {
    throw new ApiError(400, "INVALID_PLAYER", "Người chơi được mời không hợp lệ.");
  }
  if (inviteeAccountId === String(account.id)) {
    throw new ApiError(400, "CANNOT_INVITE_SELF", "Không thể tự mời chính mình.");
  }

  await withTransaction(async (client) => {
    const roomResult = await client.query(
      `SELECT room.id
         FROM game_room_members member
         JOIN game_rooms room ON room.id = member.room_id
        WHERE member.account_id = $1
          AND room.status = 'waiting'
        FOR UPDATE OF room`,
      [account.id],
    );
    if (roomResult.rowCount !== 1) {
      throw new ApiError(
        409,
        "ROOM_REQUIRED",
        "Chỉ có thể mời khi đang ở trong phòng đấu.",
      );
    }

    const targetResult = await client.query(
      `SELECT profile.account_id
         FROM player_profiles profile
         JOIN online_presence presence
           ON presence.account_id = profile.account_id
          AND presence.lease_expires_at > NOW()
        WHERE profile.account_id = $1
          AND NOT EXISTS (
            SELECT 1
              FROM game_room_members member
             WHERE member.room_id = $2
               AND member.account_id = profile.account_id
          )`,
      [inviteeAccountId, roomResult.rows[0].id],
    );
    if (targetResult.rowCount !== 1) {
      throw new ApiError(
        409,
        "PLAYER_NOT_INVITABLE",
        "Người chơi đang offline hoặc đã ở trong phòng.",
      );
    }

    await client.query(
      `INSERT INTO game_room_invitations (
         room_id,
         inviter_account_id,
         invitee_account_id
       )
       VALUES ($1, $2, $3)
       ON CONFLICT (room_id, invitee_account_id)
         WHERE status = 'pending'
       DO UPDATE SET
         inviter_account_id = EXCLUDED.inviter_account_id,
         created_at = NOW(),
         expires_at = NOW() + INTERVAL '5 minutes'`,
      [roomResult.rows[0].id, account.id, inviteeAccountId],
    );
  });

  sendJson(response, 201, {
    ok: true,
    invited_account_id: inviteeAccountId,
  });
}

async function getAdminOverview(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin:${account.id}`, 120, 60);

  const result = await pool.query(
    `SELECT
       (SELECT COUNT(*)::int FROM accounts) AS total_accounts,
       (SELECT COUNT(*)::int FROM accounts WHERE role = 'admin') AS total_admins,
       (SELECT COUNT(*)::int FROM accounts WHERE status = 'active') AS active_accounts,
       (SELECT COUNT(*)::int FROM online_presence WHERE lease_expires_at > NOW()) AS online_players,
       (SELECT COUNT(*)::int FROM login_queue WHERE expires_at > NOW()) AS queued_players,
       (SELECT COUNT(*)::int FROM security_events
         WHERE severity IN ('high', 'critical')
           AND occurred_at >= NOW() - INTERVAL '1 hour') AS serious_security_events_1h`,
  );

  sendJson(response, 200, {
    ok: true,
    overview: {
      ...result.rows[0],
      battle_runtime: battleMemoryWorkers
        ? { mode: "memory_worker", ...battleMemoryWorkers.stats() }
        : { mode: config.battleRuntimeEnabled ? "postgres_ticker" : "disabled" },
      rate_limit: rateLimiter.health(),
      security_telemetry: securityTelemetry.health(),
    },
  });
}

async function getAdminSecurityEvents(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin:${account.id}`, 120, 60);
  const url = new URL(request.url, "http://localhost");
  const beforeIdText = String(url.searchParams.get("before_id") ?? "");
  const beforeId = /^\d+$/.test(beforeIdText) ? beforeIdText : null;
  const requestedLimit = Number.parseInt(url.searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(100, Math.max(1, requestedLimit))
    : 50;
  const result = await pool.query(
    `SELECT id::text, event_type, severity, source, node_id,
            account_id::text, session_id::text, match_id::text, route,
            source_ip_hash, details, occurred_at
       FROM security_events
      WHERE ($1::bigint IS NULL OR id < $1)
      ORDER BY id DESC
      LIMIT $2`,
    [beforeId, limit],
  );
  sendJson(response, 200, {
    ok: true,
    events: result.rows,
    next_before_id: result.rows.at(-1)?.id ?? null,
  });
}

async function getAdminAccounts(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin:${account.id}`, 120, 60);

  const url = new URL(request.url, "http://localhost");
  const search = String(url.searchParams.get("search") ?? "").trim().slice(0, 50);
  const requestedPage = Number.parseInt(url.searchParams.get("page") ?? "1", 10);
  const requestedPageSize = Number.parseInt(
    url.searchParams.get("page_size") ?? "25",
    10,
  );
  const page = Number.isFinite(requestedPage) && requestedPage > 0
    ? requestedPage
    : 1;
  const pageSize = Number.isFinite(requestedPageSize)
    ? Math.min(100, Math.max(10, requestedPageSize))
    : 25;
  const offset = (page - 1) * pageSize;

  const result = await pool.query(
    `SELECT a.id, a.username, a.role, a.status, a.created_at, a.last_login_at,
            p.display_name, p.level,
            COUNT(*) OVER()::int AS total_count
       FROM accounts a
       LEFT JOIN player_profiles p ON p.account_id = a.id
      WHERE $1 = ''
         OR a.username ILIKE ('%' || $1 || '%')
         OR COALESCE(p.display_name, '') ILIKE ('%' || $1 || '%')
      ORDER BY a.created_at DESC, a.id DESC
      LIMIT $2 OFFSET $3`,
    [search, pageSize, offset],
  );

  const total = result.rows[0]?.total_count ?? 0;
  const accounts = result.rows.map(({ total_count: _totalCount, ...row }) => row);
  sendJson(response, 200, {
    ok: true,
    accounts,
    pagination: {
      page,
      page_size: pageSize,
      total,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  });
}

async function getAdminShopEditor(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin-shop-read:${account.id}`, 120, 60);
  const editor = await withReadTransaction((client) => readShopEditorState(client));
  sendJson(response, 200, { ok: true, editor });
}

async function uploadAdminContentAsset(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin-content-upload:${account.id}`, 30, 60);
  const body = await readBody(request, config.contentMaxImageBytes + 1);
  const asset = await withTransaction((client) => saveImageAsset({
    assetId: request.headers["x-asset-id"],
    originalFilename: request.headers["x-original-filename"],
    body,
    uploadedBy: account.id,
    query: (sql, parameters) => client.query(sql, parameters),
  }));
  securityTelemetry.record({
    eventType: "admin.content_asset_uploaded",
    severity: "info",
    source: "admin",
    route: "/api/admin/content/assets",
    accountId: account.id,
    sessionId: account.session_id,
    details: { asset_id: asset.asset_id, sha256: asset.sha256, byte_size: asset.byte_size },
  });
  sendJson(response, 201, {
    ok: true,
    asset: { ...asset, byte_size: Number(asset.byte_size), uri: `content://${asset.asset_id}` },
  });
}

async function saveAdminShopDraft(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin-shop-write:${account.id}`, 30, 60);
  const body = await readJson(request, SHOP_DRAFT_JSON_LIMIT);
  const draft = await withTransaction((client) =>
    saveShopDraft(client, account.id, body?.catalog)
  );
  sendJson(response, 200, { ok: true, draft });
}

async function publishAdminShopDraft(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin-shop-publish:${account.id}`, 10, 60);
  const result = await withTransaction((client) => publishShopDraft(client, account.id));
  securityTelemetry.record({
    eventType: "admin.shop_catalog_published",
    severity: "info",
    source: "admin",
    route: "/api/admin/shop/publish",
    accountId: account.id,
    sessionId: account.session_id,
    details: { release_id: result.release.id, revision: result.release.catalog_revision },
  });
  sendJson(response, 200, { ok: true, ...result });
}

async function rollbackAdminShopRelease(request, response) {
  const account = await requireSession(request);
  requireRole(account, "admin");
  await consumeRateLimit(`admin-shop-publish:${account.id}`, 10, 60);
  const body = await readJson(request);
  const result = await withTransaction((client) =>
    rollbackShopRelease(client, account.id, body?.release_id)
  );
  securityTelemetry.record({
    eventType: "admin.shop_catalog_rolled_back",
    severity: "medium",
    source: "admin",
    route: "/api/admin/shop/rollback",
    accountId: account.id,
    sessionId: account.session_id,
    details: {
      release_id: result.release.id,
      rollback_of: result.release.rollback_of,
      revision: result.release.catalog_revision,
    },
  });
  sendJson(response, 200, { ok: true, ...result });
}

async function getContentManifest(_request, response) {
  const manifest = await readPublishedManifest((sql, parameters) =>
    pool.query(sql, parameters)
  );
  sendJson(response, 200, {
    ok: true,
    manifest: materializeManifest(manifest, config.contentPublicBaseUrl),
  });
}

const routes = new Map([
  ["POST /api/auth/register", register],
  ["POST /api/auth/login", login],
  ["GET /api/auth/session", getSession],
  ["POST /api/auth/logout", logout],
  ["POST /api/characters", createCharacter],
  ["POST /api/admission/join", joinQueue],
  ["GET /api/admission/status", queueStatus],
  ["POST /api/admission/heartbeat", heartbeat],
  ["POST /api/admission/leave", leaveQueue],
  ["GET /api/lobby", getLobby],
  ["GET /api/shop/catalog", getShopCatalog],
  ["POST /api/shop/purchases", purchaseShopOffer],
  ["GET /api/inventory", getPlayerInventory],
  ["GET /api/social/players", getSocialPlayers],
  ["POST /api/social/room-invitations", inviteSocialPlayerToRoom],
  ["GET /api/friends", getFriends],
  ["POST /api/friends/requests", sendFriendRequest],
  ["POST /api/friends/requests/accept", acceptFriendRequest],
  ["POST /api/friends/requests/decline", declineFriendRequest],
  ["POST /api/friends/remove", removeFriend],
  ["POST /api/friends/block", blockPlayer],
  ["POST /api/friends/unblock", unblockPlayer],
  ["GET /api/rooms", getGameRooms],
  ["GET /api/rooms/current", getCurrentGameRoom],
  ["GET /api/rooms/maps", getGameMaps],
  ["POST /api/rooms/create", createPlayerGameRoom],
  ["POST /api/rooms/join", joinPlayerGameRoom],
  ["POST /api/rooms/quick-join", quickJoinPlayerGameRoom],
  ["POST /api/rooms/map", selectPlayerGameRoomMap],
  ["POST /api/rooms/start", startPlayerGameRoom],
  ["POST /api/rooms/cancel-matchmaking", cancelPlayerGameRoomMatchmaking],
  ["GET /api/rooms/match", getCurrentGameMatch],
  ["GET /api/rooms/match/chat", getPlayerGameMatchTeamChat],
  ["POST /api/rooms/match/chat", sendPlayerGameMatchTeamChat],
  ["POST /api/rooms/match/confirm", confirmPlayerGameMatch],
  ["POST /api/rooms/match/tank", selectPlayerGameMatchTank],
  ["POST /api/rooms/match/skin", equipPlayerGameMatchSkin],
  ["POST /api/rooms/match/deploy", deployPlayerGameMatchTank],
  ["POST /api/rooms/match/load", reportPlayerGameMatchLoad],
  ["GET /api/rooms/match/battle", getPlayerBattleSnapshot],
  ["POST /api/rooms/match/battle/commands", submitPlayerBattleCommand],
  ["POST /api/rooms/match/battle/realtime-ticket", createPlayerBattleRealtimeTicket],
  ["POST /api/rooms/leave", leavePlayerGameRoom],
  ["POST /api/tanks/primary", setPrimaryTank],
  ["POST /api/tanks/skin/equip", equipTankSkin],
  ["POST /api/rewards/newcomer-tank/claim", claimNewcomerTank],
  ["GET /api/chat/messages", getWorldChatMessages],
  ["POST /api/chat/messages", sendWorldChatMessage],
  ["GET /api/admin/overview", getAdminOverview],
  ["GET /api/admin/accounts", getAdminAccounts],
  ["GET /api/admin/security-events", getAdminSecurityEvents],
  ["GET /api/admin/shop/editor", getAdminShopEditor],
  ["POST /api/admin/content/assets", uploadAdminContentAsset],
  ["POST /api/admin/shop/draft", saveAdminShopDraft],
  ["POST /api/admin/shop/publish", publishAdminShopDraft],
  ["POST /api/admin/shop/rollback", rollbackAdminShopRelease],
  ["GET /api/content/manifest", getContentManifest],
]);

const server = createServer(async (request, response) => {
  const requestId = randomUUID();
  const requestStartedAt = process.hrtime.bigint();
  let metricRoute = "unmatched";
  response.setHeader("X-Request-Id", requestId);
  response.once("finish", () => {
    const durationSeconds = Number(process.hrtime.bigint() - requestStartedAt) / 1e9;
    httpMetrics.record(
      String(request.method ?? "UNKNOWN"),
      metricRoute,
      response.statusCode,
      durationSeconds,
    );
  });
  if (request.method === "OPTIONS") {
    metricRoute = "options";
    sendJson(response, 204, {});
    return;
  }

  try {
    const url = new URL(request.url, "http://localhost");

    if (request.method === "GET" && url.pathname === "/health/live") {
      metricRoute = "/health/live";
      sendJson(response, 200, { ok: true, service: "bangbang-server" });
      return;
    }

    if (
      request.method === "GET"
      && (url.pathname === "/health" || url.pathname === "/health/ready")
    ) {
      metricRoute = url.pathname;
      if (shuttingDown) {
        throw new ApiError(503, "SERVER_DRAINING", "Máy chủ đang dừng an toàn.", 1);
      }
      await pool.query("SELECT 1");
      const rateLimitHealth = rateLimiter.health();
      if (!rateLimitHealth.ready) {
        throw new ApiError(503, "RATE_LIMIT_UNAVAILABLE", "Rate limiter chưa sẵn sàng.", 1);
      }
      sendJson(response, 200, {
        ok: true,
        service: "bangbang-server",
        rate_limit: rateLimiter.health(),
        security_telemetry: securityTelemetry.health(),
        battle_runtime: battleMemoryWorkers
          ? "memory_worker"
          : (config.battleRuntimeEnabled ? "postgres_ticker" : "disabled"),
      });
      return;
    }

    if (request.method === "GET" && url.pathname === "/metrics") {
      metricRoute = "/metrics";
      if (!config.metricsEnabled) {
        throw new ApiError(404, "NOT_FOUND", "Không tìm thấy API.");
      }
      if (!metricsAuthorized(request)) {
        throw new ApiError(401, "UNAUTHORIZED", "Metrics yêu cầu token riêng.");
      }
      response.writeHead(200, {
        "Content-Type": "text/plain; version=0.0.4; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
      });
      response.end(httpMetrics.render(operationalGauges()));
      return;
    }

    if (request.method === "GET" && url.pathname.startsWith("/content/")) {
      metricRoute = "/content/:asset";
      const content = await readContentFile(
        decodeURIComponent(url.pathname.slice("/content/".length)),
        (sql, parameters) => pool.query(sql, parameters),
      );
      response.writeHead(200, {
        "Content-Type": content.media_type,
        "Content-Length": String(content.body.length),
        "Cache-Control": "public, max-age=31536000, immutable",
        "ETag": `\"${content.sha256}\"`,
        "Access-Control-Allow-Origin": config.allowedOrigin,
        "X-Content-Type-Options": "nosniff",
      });
      response.end(content.body);
      return;
    }

    const handler = routes.get(`${request.method} ${url.pathname}`);
    if (!handler) {
      throw new ApiError(404, "NOT_FOUND", "Không tìm thấy API.");
    }
    metricRoute = url.pathname;

    await handler(request, response);
  } catch (error) {
    const knownError =
      error instanceof ApiError ||
      error instanceof GameRoomError ||
      error instanceof EconomyError ||
      error instanceof BattleRuntimeError ||
      error instanceof ContentDeliveryError ||
      error instanceof ShopPublishingError ||
      error instanceof CatalogValidationError;
    const status = error instanceof CatalogValidationError
      ? 400
      : (knownError ? error.status : 500);
    const code = error instanceof CatalogValidationError
      ? "INVALID_SHOP_CATALOG"
      : (knownError ? error.code : "INTERNAL_ERROR");
    const message =
      knownError ? error.message : "Máy chủ đang gặp lỗi.";

    if (status >= 500) {
      console.error(error);
    }
    if (
      status === 401
      || status === 403
      || status === 429
      || code === "INVALID_JSON"
      || code === "BODY_TOO_LARGE"
      || String(code).startsWith("BATTLE_SEQUENCE_")
      || String(code).startsWith("INVALID_BATTLE_")
    ) {
      securityTelemetry.record({
        eventType: `http.${String(code).toLowerCase()}`,
        severity: status === 403 || String(code).includes("CONFLICT")
          ? "high"
          : "medium",
        source: "http",
        route: requestRoute(request),
        ip: clientIp(request),
        accountId: request.authAccount?.id,
        sessionId: request.authAccount?.session_id,
        details: { status, code, request_id: requestId },
      });
    }
    const headers = error?.retryAfter
      ? { "Retry-After": String(error.retryAfter) }
      : {};
    const errorPayload = { code, message };
    if (error?.retryAfter) {
      errorPayload.retry_after_seconds = error.retryAfter;
    }
    if (error?.retryAfterMs) {
      errorPayload.retry_after_ms = error.retryAfterMs;
    }
    if (error?.expectedSequence) {
      errorPayload.expected_sequence = error.expectedSequence;
    }
    sendJson(response, status, { ok: false, error: errorPayload }, headers);
  }
});

server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.keepAliveTimeout = 5_000;

const battleRealtime = attachBattleRealtime(server, {
  authenticate: authenticateBattleRealtime,
  initialSnapshot: battleService.getSnapshot,
  readSnapshot: battleService.readSnapshot,
  submitCommand: battleService.submitCommand,
  validateSession: isRealtimeSessionActive,
  allowedOrigin: config.allowedOrigin,
  snapshotMs: config.battleRealtimeSnapshotMs,
  fullSnapshotMs: config.battleRealtimeFullSnapshotMs,
  deltaMaxRatioBasisPoints: config.battleRealtimeDeltaMaxRatioBasisPoints,
  heartbeatMs: config.battleRealtimeHeartbeatMs,
  messageLimit: config.battleRealtimeMessageLimit,
  messageWindowMs: config.battleRealtimeMessageWindowMs,
  maxBufferedBytes: config.battleRealtimeMaxBufferedBytes,
  consumeRateLimit: (key, limit, windowMs) => (
    rateLimiter.consume(key, limit, windowMs)
  ),
  clientIp,
  recordSecurityEvent: (event) => securityTelemetry.record(event),
});

server.listen(config.port, config.host, () => {
  console.log(`BangBang server listening on http://${config.host}:${config.port}`);
});

let stopBattleRuntime = async () => {};
if (config.battleRuntimeEnabled) {
  if (battleMemoryWorkers) {
    battleMemoryWorkers.start();
    stopBattleRuntime = () => battleMemoryWorkers.stop();
  } else {
    stopBattleRuntime = startBattleTicker();
  }
}

let shutdownPromise = null;

function shutdown() {
  if (shutdownPromise) {
    return shutdownPromise;
  }
  shuttingDown = true;
  shutdownPromise = (async () => {
    let exitCode = 0;
    try {
      await battleRealtime.close();
      await stopBattleRuntime();
    } catch (error) {
      exitCode = 1;
      console.error("Server shutdown checkpoint failed:", error);
    }
    await new Promise((resolve) => server.close(() => resolve()));
    await securityTelemetry.close();
    await rateLimiter.close();
    await pool.end();
    process.exit(exitCode);
  })();
  return shutdownPromise;
}

process.on("SIGINT", () => { void shutdown(); });
process.on("SIGTERM", () => { void shutdown(); });
