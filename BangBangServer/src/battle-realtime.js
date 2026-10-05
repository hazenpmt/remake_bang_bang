import WebSocket, { WebSocketServer } from "ws";

import { BATTLE_PROTOCOL_VERSION } from "./battle-policy.js";

export const BATTLE_REALTIME_PATH = "/api/realtime/battle";
export const BATTLE_REALTIME_TRANSPORT_VERSION = 3;
const MAX_REQUEST_ID = Number.MAX_SAFE_INTEGER;
const MAX_MESSAGE_BYTES = 16 * 1024;

function cloneJson(value) {
  if (value === undefined) {
    return undefined;
  }
  return JSON.parse(JSON.stringify(value));
}

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function snapshotRowKey(row, keyFields) {
  if (!row || typeof row !== "object" || Array.isArray(row)) {
    return null;
  }
  const values = [];
  for (const field of keyFields) {
    if (!(field in row)) {
      return null;
    }
    values.push(String(row[field]));
  }
  return values.join(":");
}

function buildObjectPatch(previous, current, excludedKeys = new Set()) {
  const set = {};
  const unset = [];
  const keys = new Set([...Object.keys(previous), ...Object.keys(current)]);
  for (const key of [...keys].sort()) {
    if (excludedKeys.has(key)) {
      continue;
    }
    if (!(key in current)) {
      unset.push(key);
    } else if (!(key in previous) || !sameJson(previous[key], current[key])) {
      set[key] = cloneJson(current[key]);
    }
  }
  return { set, unset };
}

function buildRowPatches(previousRows, currentRows, keyFields) {
  if (!Array.isArray(previousRows) || !Array.isArray(currentRows)) {
    return null;
  }
  const previousByKey = new Map();
  const currentByKey = new Map();
  for (const row of previousRows) {
    const key = snapshotRowKey(row, keyFields);
    if (key == null || previousByKey.has(key)) {
      return null;
    }
    previousByKey.set(key, row);
  }
  for (const row of currentRows) {
    const key = snapshotRowKey(row, keyFields);
    if (key == null || currentByKey.has(key)) {
      return null;
    }
    currentByKey.set(key, row);
  }
  if (
    previousByKey.size !== currentByKey.size
    || [...previousByKey.keys()].some((key) => !currentByKey.has(key))
    || [...previousByKey.keys()].some(
      (key, index) => [...currentByKey.keys()][index] !== key,
    )
  ) {
    return null;
  }
  const excluded = new Set(keyFields);
  const patches = [];
  for (const key of [...currentByKey.keys()].sort()) {
    const patch = buildObjectPatch(
      previousByKey.get(key),
      currentByKey.get(key),
      excluded,
    );
    if (Object.keys(patch.set).length === 0 && patch.unset.length === 0) {
      continue;
    }
    const currentRow = currentByKey.get(key);
    patches.push({
      ...Object.fromEntries(keyFields.map((field) => [field, currentRow[field]])),
      ...patch,
    });
  }
  return patches;
}

export function buildBattleSnapshotDelta(previous, current) {
  if (
    !previous || typeof previous !== "object" || Array.isArray(previous)
    || !current || typeof current !== "object" || Array.isArray(current)
    || String(previous.match_id ?? "") !== String(current.match_id ?? "")
    || Number(previous.state_epoch ?? 0) !== Number(current.state_epoch ?? 0)
  ) {
    return null;
  }
  const entities = buildRowPatches(
    previous.entities ?? [],
    current.entities ?? [],
    ["team_no", "slot_no"],
  );
  const worldEntities = buildRowPatches(
    previous.world_entities ?? [],
    current.world_entities ?? [],
    ["entity_key"],
  );
  if (entities == null || worldEntities == null) {
    return null;
  }
  const top = buildObjectPatch(
    previous,
    current,
    new Set(["entities", "world_entities"]),
  );
  return {
    set: top.set,
    unset: top.unset,
    entities,
    world_entities: worldEntities,
  };
}

function applyRowPatches(rows, patches, keyFields) {
  if (!Array.isArray(rows) || !Array.isArray(patches)) {
    return null;
  }
  const result = cloneJson(rows);
  const indexByKey = new Map();
  for (let index = 0; index < result.length; index += 1) {
    const key = snapshotRowKey(result[index], keyFields);
    if (key == null || indexByKey.has(key)) {
      return null;
    }
    indexByKey.set(key, index);
  }
  for (const patch of patches) {
    const key = snapshotRowKey(patch, keyFields);
    if (
      key == null || !indexByKey.has(key)
      || !patch.set || typeof patch.set !== "object" || Array.isArray(patch.set)
      || !Array.isArray(patch.unset)
    ) {
      return null;
    }
    const row = result[indexByKey.get(key)];
    for (const [field, value] of Object.entries(patch.set)) {
      if (keyFields.includes(field)) {
        return null;
      }
      row[field] = cloneJson(value);
    }
    for (const field of patch.unset) {
      if (typeof field !== "string" || keyFields.includes(field)) {
        return null;
      }
      delete row[field];
    }
  }
  return result;
}

export function applyBattleSnapshotDelta(previous, delta) {
  if (
    !previous || typeof previous !== "object" || Array.isArray(previous)
    || !delta || typeof delta !== "object" || Array.isArray(delta)
    || !delta.set || typeof delta.set !== "object" || Array.isArray(delta.set)
    || !Array.isArray(delta.unset)
  ) {
    return null;
  }
  const result = cloneJson(previous);
  for (const [key, value] of Object.entries(delta.set)) {
    if (key === "entities" || key === "world_entities") {
      return null;
    }
    result[key] = cloneJson(value);
  }
  for (const key of delta.unset) {
    if (
      typeof key !== "string"
      || key === "entities"
      || key === "world_entities"
    ) {
      return null;
    }
    delete result[key];
  }
  const entities = applyRowPatches(
    result.entities ?? [],
    delta.entities,
    ["team_no", "slot_no"],
  );
  const worldEntities = applyRowPatches(
    result.world_entities ?? [],
    delta.world_entities,
    ["entity_key"],
  );
  if (entities == null || worldEntities == null) {
    return null;
  }
  result.entities = entities;
  result.world_entities = worldEntities;
  return result;
}

function realtimeError(code, message, status = 400, extra = {}) {
  return { ok: false, status, error: { code, message, ...extra } };
}

function ownKeys(value) {
  return Object.keys(value).sort();
}

function hasOnlyKeys(value, allowed) {
  return ownKeys(value).every((key) => allowed.has(key));
}

function validRequestId(value) {
  return Number.isSafeInteger(value) && value > 0 && value <= MAX_REQUEST_ID;
}

export function validateBattleRealtimeMessage(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Realtime message must be a JSON object.");
  }
  const type = value.type;
  if (type === "command") {
    if (!hasOnlyKeys(value, new Set(["type", "request_id", "sequence", "command"]))) {
      throw new Error("Command message contains unsupported fields.");
    }
    if (!validRequestId(value.request_id)) {
      throw new Error("Command request_id is invalid.");
    }
    if (!Number.isSafeInteger(value.sequence) || value.sequence <= 0) {
      throw new Error("Command sequence is invalid.");
    }
    if (!value.command || typeof value.command !== "object" || Array.isArray(value.command)) {
      throw new Error("Command payload is invalid.");
    }
    return {
      type,
      requestId: value.request_id,
      body: { sequence: value.sequence, command: value.command },
    };
  }
  if (type === "snapshot_request") {
    if (!hasOnlyKeys(value, new Set(["type", "request_id"]))) {
      throw new Error("Snapshot request contains unsupported fields.");
    }
    if (!validRequestId(value.request_id)) {
      throw new Error("Snapshot request_id is invalid.");
    }
    return { type, requestId: value.request_id };
  }
  if (type === "ping") {
    if (!hasOnlyKeys(value, new Set(["type", "client_time"]))) {
      throw new Error("Ping message contains unsupported fields.");
    }
    if (
      value.client_time != null
      && (!Number.isFinite(value.client_time) || value.client_time < 0)
    ) {
      throw new Error("Ping client_time is invalid.");
    }
    return { type, clientTime: value.client_time ?? null };
  }
  throw new Error("Realtime message type is not supported.");
}

function publicError(error) {
  const status = Number(error?.status) || 500;
  const known = status >= 400 && status < 500;
  const result = realtimeError(
    known ? String(error.code ?? "REALTIME_REQUEST_FAILED") : "INTERNAL_ERROR",
    known ? String(error.message ?? "Yêu cầu realtime không hợp lệ.") : "Máy chủ đang gặp lỗi.",
    status,
  );
  if (error?.retryAfterMs) {
    result.error.retry_after_ms = Number(error.retryAfterMs);
  }
  if (error?.expectedSequence) {
    result.error.expected_sequence = Number(error.expectedSequence);
  }
  return result;
}

function rejectUpgrade(socket, status, reason) {
  if (socket.destroyed) {
    return;
  }
  const body = JSON.stringify({ ok: false, error: { code: reason } });
  const statusText = new Map([
    [400, "Bad Request"],
    [401, "Unauthorized"],
    [403, "Forbidden"],
    [404, "Not Found"],
    [429, "Too Many Requests"],
    [503, "Service Unavailable"],
  ]).get(status) ?? "Bad Request";
  socket.write(
    `HTTP/1.1 ${status} ${statusText}\r\n`
      + "Connection: close\r\n"
      + "Content-Type: application/json; charset=utf-8\r\n"
      + `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n`
      + body,
  );
  socket.destroy();
}

function originAllowed(request, allowedOrigin) {
  const origin = request.headers.origin;
  return !origin || allowedOrigin === "*" || origin === allowedOrigin;
}

export function attachBattleRealtime(server, dependencies = {}) {
  const authenticate = dependencies.authenticate;
  const initialSnapshot = dependencies.initialSnapshot;
  const readSnapshot = dependencies.readSnapshot;
  const submitCommand = dependencies.submitCommand;
  const validateSession = dependencies.validateSession ?? (async () => true);
  if (
    typeof authenticate !== "function"
    || typeof initialSnapshot !== "function"
    || typeof readSnapshot !== "function"
    || typeof submitCommand !== "function"
    || typeof validateSession !== "function"
  ) {
    throw new Error("Battle realtime dependencies are incomplete.");
  }

  const snapshotMs = Math.max(
    50,
    Number(dependencies.snapshotMs ?? 100),
  );
  const fullSnapshotMs = Math.max(
    1_000,
    Number(dependencies.fullSnapshotMs ?? 5_000),
  );
  const deltaMaxRatioBasisPoints = Math.min(
    10_000,
    Math.max(1, Number(dependencies.deltaMaxRatioBasisPoints ?? 8_500)),
  );
  const heartbeatMs = Math.max(
    1_000,
    Number(dependencies.heartbeatMs ?? 10_000),
  );
  const messageLimit = Math.max(
    10,
    Number(dependencies.messageLimit ?? 80),
  );
  const messageWindowMs = Math.max(
    250,
    Number(dependencies.messageWindowMs ?? 1_000),
  );
  const maxBufferedBytes = Math.max(
    64 * 1024,
    Number(dependencies.maxBufferedBytes ?? 256 * 1024),
  );
  const allowedOrigin = String(dependencies.allowedOrigin ?? "*");
  const sharedRateLimit = typeof dependencies.consumeRateLimit === "function"
    ? dependencies.consumeRateLimit
    : null;
  const recordSecurityEvent = typeof dependencies.recordSecurityEvent === "function"
    ? dependencies.recordSecurityEvent
    : () => {};
  const requestIp = typeof dependencies.clientIp === "function"
    ? dependencies.clientIp
    : (request) => request.socket.remoteAddress ?? "unknown";
  const socketsByAccount = new Map();
  const messageBucketsByAccount = new Map();
  const connectionBucketsByAccount = new Map();
  const wss = new WebSocketServer({
    noServer: true,
    clientTracking: false,
    maxPayload: MAX_MESSAGE_BYTES,
    perMessageDeflate: false,
    allowSynchronousEvents: false,
  });
  let closed = false;

  function send(context, value) {
    if (context.socket.readyState !== WebSocket.OPEN) {
      return false;
    }
    if (context.socket.bufferedAmount > maxBufferedBytes) {
      context.socket.close(1009, "Realtime client is too slow.");
      return false;
    }
    context.socket.send(JSON.stringify(value));
    return true;
  }

  async function pushSnapshot(context, force = false, initialize = false) {
    if (context.snapshotInFlight || context.socket.readyState !== WebSocket.OPEN) {
      return;
    }
    context.snapshotInFlight = true;
    try {
      const snapshot = initialize
        ? await initialSnapshot(context.account.id)
        : await readSnapshot(context.account.id);
      const revision = Number(snapshot.revision);
      const now = Date.now();
      if (
        force
        || revision !== context.lastRevision
        || now - context.lastSnapshotAt >= 1_000
      ) {
        const nextSerial = context.snapshotSerial + 1;
        const fullMessage = {
          type: "snapshot",
          snapshot_serial: nextSerial,
          snapshot,
        };
        const delta = context.lastPushedSnapshot == null
          ? null
          : buildBattleSnapshotDelta(context.lastPushedSnapshot, snapshot);
        const deltaMessage = delta == null ? null : {
          type: "snapshot_delta",
          base_snapshot_serial: context.snapshotSerial,
          snapshot_serial: nextSerial,
          match_id: String(snapshot.match_id ?? ""),
          state_epoch: Number(snapshot.state_epoch ?? 0),
          base_revision: Number(context.lastPushedSnapshot.revision),
          revision,
          delta,
        };
        const fullDue = (
          force
          || deltaMessage == null
          || now - context.lastFullSnapshotAt >= fullSnapshotMs
        );
        const deltaIsWorthwhile = !fullDue && (
          Buffer.byteLength(JSON.stringify(deltaMessage)) * 10_000
          <= Buffer.byteLength(JSON.stringify(fullMessage))
            * deltaMaxRatioBasisPoints
        );
        const message = deltaIsWorthwhile ? deltaMessage : fullMessage;
        if (send(context, message)) {
          context.snapshotSerial = nextSerial;
          context.lastPushedSnapshot = cloneJson(snapshot);
          context.lastRevision = revision;
          context.lastSnapshotAt = now;
          if (!deltaIsWorthwhile) {
            context.lastFullSnapshotAt = now;
          }
        }
      }
    } catch (error) {
      const result = publicError(error);
      send(context, { type: "error", request_id: null, ...result });
      if (result.status === 404 || result.error.code === "BATTLE_SANDBOX_LOCAL") {
        context.socket.close(4004, "Battle is unavailable.");
      } else if (result.status >= 500) {
        console.error("Battle realtime snapshot failed:", error);
      }
    } finally {
      context.snapshotInFlight = false;
    }
  }

  async function consumeMessageBudget(context) {
    const now = Date.now();
    const accountKey = String(context.account.id);
    if (sharedRateLimit) {
      const result = await sharedRateLimit(
        `battle-realtime-message:${accountKey}`,
        messageLimit,
        messageWindowMs,
      );
      return result.allowed;
    }
    let bucket = messageBucketsByAccount.get(accountKey);
    if (!bucket || now - bucket.windowStartedAt >= messageWindowMs) {
      bucket = { windowStartedAt: now, count: 0, lastSeenAt: now };
      messageBucketsByAccount.set(accountKey, bucket);
    }
    bucket.count += 1;
    bucket.lastSeenAt = now;
    return bucket.count <= messageLimit;
  }

  async function consumeConnectionBudget(account) {
    const accountKey = String(account.id);
    const now = Date.now();
    if (sharedRateLimit) {
      const result = await sharedRateLimit(
        `battle-realtime-connect:${accountKey}`,
        12,
        10_000,
      );
      return result.allowed;
    }
    let bucket = connectionBucketsByAccount.get(accountKey);
    if (!bucket || now - bucket.windowStartedAt >= 10_000) {
      bucket = { windowStartedAt: now, count: 0, lastSeenAt: now };
      connectionBucketsByAccount.set(accountKey, bucket);
    }
    bucket.count += 1;
    bucket.lastSeenAt = now;
    return bucket.count <= 12;
  }

  async function validateContextSession(context) {
    if (context.sessionCheckInFlight || context.retired) {
      return;
    }
    context.sessionCheckInFlight = true;
    try {
      const active = await validateSession(context.account);
      context.lastSessionCheckAt = Date.now();
      if (!active) {
        context.retired = true;
        context.socket.close(4003, "Session has expired or was revoked.");
      }
    } catch (error) {
      console.error("Battle realtime session validation failed:", error);
    } finally {
      context.sessionCheckInFlight = false;
    }
  }

  async function processMessage(context, data, isBinary) {
    if (
      context.retired
      || socketsByAccount.get(String(context.account.id)) !== context
    ) {
      return;
    }
    if (isBinary) {
      recordSecurityEvent({
        eventType: "websocket.binary_message_rejected",
        severity: "medium",
        source: "websocket",
        accountId: context.account.id,
        sessionId: context.account.session_id,
        route: BATTLE_REALTIME_PATH,
        ip: requestIp(context.request),
      });
      context.socket.close(1003, "Text JSON messages are required.");
      return;
    }
    try {
      if (!(await consumeMessageBudget(context))) {
        recordSecurityEvent({
          eventType: "websocket.rate_limit_exceeded",
          severity: "high",
          source: "websocket",
          accountId: context.account.id,
          sessionId: context.account.session_id,
          route: BATTLE_REALTIME_PATH,
          ip: requestIp(context.request),
        });
        context.socket.close(1008, "Realtime message rate exceeded.");
        return;
      }
    } catch {
      recordSecurityEvent({
        eventType: "websocket.rate_limit_unavailable",
        severity: "critical",
        source: "system",
        accountId: context.account.id,
        route: BATTLE_REALTIME_PATH,
      });
      context.socket.close(1013, "Realtime traffic protection is unavailable.");
      return;
    }
    let message;
    try {
      message = validateBattleRealtimeMessage(JSON.parse(data.toString("utf8")));
    } catch (error) {
      recordSecurityEvent({
        eventType: "websocket.invalid_message",
        severity: "medium",
        source: "websocket",
        accountId: context.account.id,
        sessionId: context.account.session_id,
        route: BATTLE_REALTIME_PATH,
        ip: requestIp(context.request),
        details: { reason: error.message },
      });
      send(context, {
        type: "error",
        request_id: null,
        ...realtimeError("INVALID_REALTIME_MESSAGE", error.message),
      });
      return;
    }
    if (message.type === "ping") {
      send(context, {
        type: "pong",
        client_time: message.clientTime,
        server_time: Date.now(),
      });
      return;
    }
    try {
      if (message.type === "snapshot_request") {
        const snapshot = await readSnapshot(context.account.id);
        send(context, {
          type: "snapshot_result",
          request_id: message.requestId,
          ok: true,
          snapshot,
        });
        return;
      }
      const response = await submitCommand(context.account.id, message.body);
      send(context, {
        type: "command_result",
        request_id: message.requestId,
        ok: true,
        ...response,
      });
    } catch (error) {
      const result = publicError(error);
      recordSecurityEvent({
        eventType: `battle.${String(result.error.code).toLowerCase()}`,
        severity: result.status === 409
          ? "high"
          : (result.status >= 500 ? "critical" : "medium"),
        source: "battle",
        accountId: context.account.id,
        sessionId: context.account.session_id,
        matchId: context.lastPushedSnapshot?.match_id,
        route: BATTLE_REALTIME_PATH,
        ip: requestIp(context.request),
        details: { status: result.status, code: result.error.code },
      });
      send(context, {
        type: "error",
        request_id: message.requestId,
        ...result,
      });
      if (result.status >= 500) {
        console.error("Battle realtime request failed:", error);
      }
    }
  }

  function onConnection(socket, request, account) {
    const accountKey = String(account.id);
    const previous = socketsByAccount.get(accountKey);
    if (previous && previous.socket.readyState < WebSocket.CLOSING) {
      previous.retired = true;
      previous.socket.close(4001, "Replaced by a newer battle connection.");
    }
    const context = {
      socket,
      request,
      account,
      alive: true,
      snapshotInFlight: false,
      lastRevision: -1,
      lastSnapshotAt: 0,
      lastFullSnapshotAt: 0,
      lastPushedSnapshot: null,
      snapshotSerial: 0,
      messageQueue: Promise.resolve(),
      retired: false,
      sessionCheckInFlight: false,
      lastSessionCheckAt: Date.now(),
    };
    socketsByAccount.set(accountKey, context);
    socket.on("pong", () => {
      context.alive = true;
    });
    socket.on("message", (data, isBinary) => {
      context.messageQueue = context.messageQueue
        .then(() => processMessage(context, data, isBinary))
        .catch((error) => {
          console.error("Battle realtime message queue failed:", error);
          socket.close(1011, "Realtime request failed.");
        });
    });
    socket.on("error", (error) => {
      if (!closed) {
        console.error(`Battle realtime socket error for account ${accountKey}:`, error);
      }
    });
    socket.on("close", () => {
      if (socketsByAccount.get(accountKey) === context) {
        socketsByAccount.delete(accountKey);
      }
    });
    send(context, {
      type: "hello",
      transport_version: BATTLE_REALTIME_TRANSPORT_VERSION,
      protocol_version: BATTLE_PROTOCOL_VERSION,
      snapshot_interval_ms: snapshotMs,
      heartbeat_interval_ms: heartbeatMs,
    });
    // Initialize/advance the battle once before accepting any command on this
    // socket. Messages received during initialization remain in the same
    // promise chain and cannot race an empty participant/world state.
    context.messageQueue = pushSnapshot(context, true, true);
  }

  const upgradeHandler = async (request, socket, head) => {
    let pathname;
    try {
      pathname = new URL(request.url, "http://localhost").pathname;
    } catch {
      rejectUpgrade(socket, 400, "INVALID_REALTIME_URL");
      return;
    }
    if (pathname !== BATTLE_REALTIME_PATH) {
      rejectUpgrade(socket, 404, "NOT_FOUND");
      return;
    }
    if (!originAllowed(request, allowedOrigin)) {
      rejectUpgrade(socket, 403, "ORIGIN_FORBIDDEN");
      return;
    }
    socket.on("error", () => {});
    try {
      const account = await authenticate(request);
      if (!(await consumeConnectionBudget(account))) {
        recordSecurityEvent({
          eventType: "websocket.connection_rate_exceeded",
          severity: "high",
          source: "websocket",
          accountId: account.id,
          sessionId: account.session_id,
          route: BATTLE_REALTIME_PATH,
          ip: requestIp(request),
        });
        rejectUpgrade(socket, 429, "REALTIME_CONNECTION_RATE_EXCEEDED");
        return;
      }
      if (closed || socket.destroyed) {
        socket.destroy();
        return;
      }
      wss.handleUpgrade(request, socket, head, (websocket) => {
        onConnection(websocket, request, account);
      });
    } catch (error) {
      recordSecurityEvent({
        eventType: error?.code === "RATE_LIMIT_UNAVAILABLE"
          ? "websocket.rate_limit_unavailable"
          : "websocket.handshake_rejected",
        severity: error?.code === "RATE_LIMIT_UNAVAILABLE" ? "critical" : "medium",
        source: error?.code === "RATE_LIMIT_UNAVAILABLE" ? "system" : "websocket",
        route: BATTLE_REALTIME_PATH,
        ip: requestIp(request),
      });
      if (error?.code === "RATE_LIMIT_UNAVAILABLE") {
        rejectUpgrade(socket, 503, "RATE_LIMIT_UNAVAILABLE");
      } else {
        rejectUpgrade(socket, 401, "UNAUTHORIZED");
      }
    }
  };
  server.on("upgrade", upgradeHandler);

  const snapshotTimer = setInterval(() => {
    for (const context of socketsByAccount.values()) {
      pushSnapshot(context);
    }
  }, snapshotMs);
  snapshotTimer.unref();

  const heartbeatTimer = setInterval(() => {
    const now = Date.now();
    for (const context of socketsByAccount.values()) {
      if (!context.alive) {
        context.socket.terminate();
        continue;
      }
      context.alive = false;
      context.socket.ping();
      validateContextSession(context);
    }
    for (const [accountKey, bucket] of messageBucketsByAccount) {
      if (now - bucket.lastSeenAt > 60_000) {
        messageBucketsByAccount.delete(accountKey);
      }
    }
    for (const [accountKey, bucket] of connectionBucketsByAccount) {
      if (now - bucket.lastSeenAt > 60_000) {
        connectionBucketsByAccount.delete(accountKey);
      }
    }
  }, heartbeatMs);
  heartbeatTimer.unref();

  return {
    connectionCount() {
      return socketsByAccount.size;
    },
    revokeSession(sessionId) {
      const key = String(sessionId);
      for (const context of socketsByAccount.values()) {
        if (String(context.account.session_id) === key) {
          context.retired = true;
          context.socket.close(4003, "Session was revoked.");
        }
      }
    },
    async close() {
      if (closed) {
        return;
      }
      closed = true;
      clearInterval(snapshotTimer);
      clearInterval(heartbeatTimer);
      server.removeListener("upgrade", upgradeHandler);
      for (const context of socketsByAccount.values()) {
        context.retired = true;
        context.socket.close(1001, "Server is shutting down.");
      }
      socketsByAccount.clear();
      messageBucketsByAccount.clear();
      connectionBucketsByAccount.clear();
      await new Promise((resolve) => wss.close(() => resolve()));
    },
  };
}
