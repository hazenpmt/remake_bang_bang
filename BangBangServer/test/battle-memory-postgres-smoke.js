import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import WebSocket from "ws";

import { createBattleMemoryWorkerRegistry } from "../src/battle-memory-workers.js";
import {
  authenticateBattleRealtimeTicket,
  issueBattleRealtimeTicket,
} from "../src/battle-realtime-tickets.js";
import { pool, withTransaction } from "../src/db.js";
import { hashSessionToken } from "../src/security.js";

const suffix = String(Date.now()).slice(-8);
const username = `battle_mem_${suffix}`;
const sessionToken = `battle-memory-session-${suffix}`;
let accountId = null;
let roomId = null;
let sessionId = null;

async function setup() {
  return withTransaction(async (client) => {
    const tankResult = await client.query(
      "SELECT id, tank_key, display_name, preview_asset_key FROM tanks WHERE tank_key = 'gangtiexia03'",
    );
    assert.equal(tankResult.rowCount, 1);
    const tank = tankResult.rows[0];
    const skinResult = await client.query(
      `SELECT id, skin_key, display_name, preview_asset_key
         FROM tank_skins
        WHERE tank_id = $1 AND is_default
        LIMIT 1`,
      [tank.id],
    );
    assert.equal(skinResult.rowCount, 1);
    const skin = skinResult.rows[0];
    const accountResult = await client.query(
      `INSERT INTO accounts(username, password_hash)
       VALUES ($1, 'battle-memory-smoke-not-a-login')
       RETURNING id`,
      [username],
    );
    accountId = accountResult.rows[0].id;
    const sessionResult = await client.query(
      `INSERT INTO sessions(account_id, token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '10 minutes')
       RETURNING id`,
      [accountId, hashSessionToken(sessionToken)],
    );
    sessionId = sessionResult.rows[0].id;
    await client.query(
      `INSERT INTO player_profiles(account_id, display_name, gender, avatar_key)
       VALUES ($1, $2, 'male', 'default_male')`,
      [accountId, `BM${suffix.slice(-6)}`],
    );
    await client.query(
      "INSERT INTO player_currencies(account_id) VALUES ($1)",
      [accountId],
    );
    await client.query(
      `INSERT INTO player_tanks(
         account_id, tank_id, level, is_primary, equipped_skin_id
       ) VALUES ($1, $2, 1, TRUE, $3)`,
      [accountId, tank.id, skin.id],
    );
    await client.query(
      `INSERT INTO player_tank_skins(account_id, tank_skin_id)
       VALUES ($1, $2)`,
      [accountId, skin.id],
    );
    const roomResult = await client.query(
      `INSERT INTO game_rooms(
         tab_key, room_name, mode_key, map_key,
         max_players, status, is_test, created_by_account_id
       ) VALUES ('solo', $1, 'free', 'random', 1, 'running', FALSE, $2)
       RETURNING id`,
      [`Battle memory ${suffix}`, accountId],
    );
    roomId = roomResult.rows[0].id;
    await client.query(
      "INSERT INTO game_room_members(room_id, account_id) VALUES ($1, $2)",
      [roomId, accountId],
    );
    const matchResult = await client.query(
      `INSERT INTO game_matches(
         team_a_room_id, is_test, phase, map_key,
         confirmation_deadline, activated_at
       ) VALUES ($1, FALSE, 'active', 'random', NOW(), NOW())
       RETURNING id`,
      [roomId],
    );
    const matchId = matchResult.rows[0].id;
    await client.query(
      `INSERT INTO game_match_participants(
         match_id, team_no, slot_no, account_id, is_bot,
         display_name, gender, level, avatar_key,
         tank_key, tank_name, tank_preview_asset_key, tank_level,
         equipped_skin_key, equipped_skin_name,
         equipped_skin_preview_asset_key,
         confirmed, deployed, load_progress, load_ready
       ) VALUES (
         $1, 1, 1, $2, FALSE,
         $3, 'male', 1, 'default_male',
         $4, $5, $6, 1,
         $7, $8, $9,
         TRUE, TRUE, 100, TRUE
       )`,
      [
        matchId,
        accountId,
        `BM${suffix.slice(-6)}`,
        tank.tank_key,
        tank.display_name,
        tank.preview_asset_key,
        skin.skin_key,
        skin.display_name,
        skin.preview_asset_key,
      ],
    );
    return matchId;
  });
}

async function cleanup() {
  await withTransaction(async (client) => {
    if (roomId != null) {
      await client.query("DELETE FROM game_rooms WHERE id = $1", [roomId]);
    }
    if (accountId != null) {
      await client.query("DELETE FROM accounts WHERE id = $1", [accountId]);
    }
  });
}

async function waitForServer(baseUrl, child, stderr) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (child.exitCode != null) {
      throw new Error(`Ticket API server exited early. ${stderr.value}`);
    }
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) {
        return;
      }
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Ticket API server did not become healthy. ${stderr.value}`);
}

async function connectTicketSocket(url, ticket) {
  const socket = new WebSocket(url, {
    headers: { "X-Battle-Ticket": ticket },
  });
  const messages = [];
  socket.on("message", (data) => {
    messages.push(JSON.parse(data.toString("utf8")));
  });
  await new Promise((resolve, reject) => {
    socket.once("open", resolve);
    socket.once("error", reject);
  });
  const deadline = Date.now() + 3_000;
  while (
    !messages.some((message) => message.type === "snapshot")
    && Date.now() < deadline
  ) {
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  assert.ok(messages.some((message) => message.type === "hello"));
  assert.ok(messages.some((message) => message.type === "snapshot"));
  socket.close();
  await new Promise((resolve) => socket.once("close", resolve));
}

async function assertTicketCannotBeReused(url, ticket) {
  const socket = new WebSocket(url, {
    headers: { "X-Battle-Ticket": ticket },
  });
  const status = await new Promise((resolve, reject) => {
    socket.once("unexpected-response", (_request, response) => {
      response.resume();
      resolve(response.statusCode);
    });
    socket.once("open", () => reject(new Error("One-use ticket was accepted twice.")));
    socket.once("error", () => {});
  });
  assert.equal(status, 401);
}

const registryA = createBattleMemoryWorkerRegistry({
  instanceId: `memory-smoke-a-${suffix}`,
  checkpointMs: 60_000,
  leaseMs: 180_000,
  workerLimit: 1,
});
const registryB = createBattleMemoryWorkerRegistry({
  instanceId: `memory-smoke-b-${suffix}`,
  checkpointMs: 60_000,
  leaseMs: 180_000,
});

try {
  const matchId = await setup();
  const first = await registryA.getSnapshot(accountId);
  assert.equal(first.match_id, String(matchId));
  assert.ok(first.state_epoch > 0);
  assert.equal(first.entities.length, 1);
  assert.equal(first.world_entities.length, 49);
  registryA.start();

  const ticket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryA,
    { lifetimeSeconds: 30 },
  );
  assert.equal(ticket.match_id, String(matchId));
  assert.equal(ticket.state_epoch, first.state_epoch);
  assert.equal(ticket.websocket_url, null);
  const storedTicket = await pool.query(
    `SELECT token_hash, used_at
       FROM battle_realtime_tickets
      WHERE account_id = $1`,
    [accountId],
  );
  assert.equal(storedTicket.rowCount, 1);
  assert.notEqual(storedTicket.rows[0].token_hash.trim(), ticket.ticket);
  assert.equal(storedTicket.rows[0].used_at, null);
  await assert.rejects(
    authenticateBattleRealtimeTicket(
      { headers: { "x-battle-ticket": ticket.ticket } },
      registryB.instanceId,
    ),
    (error) => error.code === "BATTLE_TICKET_INVALID",
  );
  const expiredTicket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryA,
    { lifetimeSeconds: 30 },
  );
  await pool.query(
    `UPDATE battle_realtime_tickets
        SET created_at = NOW() - INTERVAL '10 seconds',
            expires_at = NOW() - INTERVAL '1 second'
      WHERE token_hash = $1`,
    [hashSessionToken(expiredTicket.ticket)],
  );
  await assert.rejects(
    authenticateBattleRealtimeTicket(
      { headers: { "x-battle-ticket": expiredTicket.ticket } },
      registryA.instanceId,
    ),
    (error) => error.code === "BATTLE_TICKET_INVALID",
  );
  const revokedSessionTicket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryA,
    { lifetimeSeconds: 30 },
  );
  await pool.query(
    "UPDATE sessions SET expires_at = NOW() - INTERVAL '1 second' WHERE id = $1",
    [sessionId],
  );
  await assert.rejects(
    authenticateBattleRealtimeTicket(
      { headers: { "x-battle-ticket": revokedSessionTicket.ticket } },
      registryA.instanceId,
    ),
    (error) => error.code === "BATTLE_TICKET_INVALID",
  );
  await pool.query(
    "UPDATE sessions SET expires_at = NOW() + INTERVAL '10 minutes' WHERE id = $1",
    [sessionId],
  );
  const ticketAccount = await authenticateBattleRealtimeTicket(
    { headers: { "x-battle-ticket": ticket.ticket } },
    registryA.instanceId,
  );
  assert.equal(String(ticketAccount.id), String(accountId));
  assert.equal(String(ticketAccount.session_id), String(sessionId));
  await assert.rejects(
    authenticateBattleRealtimeTicket(
      { headers: { "x-battle-ticket": ticket.ticket } },
      registryA.instanceId,
    ),
    (error) => error.code === "BATTLE_TICKET_INVALID",
  );

  const databaseBeforeMove = await pool.query(
    `SELECT match.battle_revision, battle.last_sequence
       FROM game_matches match
       JOIN game_match_battle_participants battle ON battle.match_id = match.id
      WHERE match.id = $1 AND battle.account_id = $2`,
    [matchId, accountId],
  );
  const moved = await registryA.submitCommand(accountId, {
    sequence: 1,
    command: { type: "move", x: 1, y: 0 },
  });
  assert.equal(moved.accepted_sequence, 1);
  assert.ok(moved.snapshot.revision > Number(databaseBeforeMove.rows[0].battle_revision));
  const databaseAfterMove = await pool.query(
    `SELECT match.battle_revision, battle.last_sequence
       FROM game_matches match
       JOIN game_match_battle_participants battle ON battle.match_id = match.id
      WHERE match.id = $1 AND battle.account_id = $2`,
    [matchId, accountId],
  );
  assert.equal(Number(databaseAfterMove.rows[0].last_sequence), 0);
  assert.equal(
    Number(databaseAfterMove.rows[0].battle_revision),
    Number(databaseBeforeMove.rows[0].battle_revision),
  );

  await assert.rejects(
    registryB.getSnapshot(accountId),
    (error) => error.code === "BATTLE_WORKER_BUSY",
  );

  const viewer = moved.snapshot.entities[0];
  const attacked = await registryA.submitCommand(accountId, {
    sequence: 2,
    command: {
      type: "basic_attack",
      target_x: viewer.position_x + 100,
      target_y: viewer.position_y,
    },
  });
  assert.equal(attacked.accepted_sequence, 2);
  assert.equal(attacked.replayed, false);
  const durable = await pool.query(
    `SELECT match.battle_checkpoint_at,
            battle.last_sequence,
            (SELECT COUNT(*) FROM game_match_battle_commands command
              WHERE command.match_id = match.id) AS command_count,
            (SELECT COUNT(*) FROM game_match_battle_events event
              WHERE event.match_id = match.id) AS event_count
       FROM game_matches match
       JOIN game_match_battle_participants battle ON battle.match_id = match.id
      WHERE match.id = $1 AND battle.account_id = $2`,
    [matchId, accountId],
  );
  assert.ok(durable.rows[0].battle_checkpoint_at);
  assert.equal(Number(durable.rows[0].last_sequence), 2);
  assert.equal(Number(durable.rows[0].command_count), 2);
  const eventCount = Number(durable.rows[0].event_count);
  assert.ok(eventCount >= 1);

  await registryA.checkpointMatch(matchId);
  const eventReplayCheck = await pool.query(
    "SELECT COUNT(*)::int AS count FROM game_match_battle_events WHERE match_id = $1",
    [matchId],
  );
  assert.equal(eventReplayCheck.rows[0].count, eventCount);

  const staleRouteTicket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryA,
    { lifetimeSeconds: 30 },
  );
  await registryA.stop();
  const leaseAfterStop = await pool.query(
    `SELECT battle_worker_id, battle_worker_lease_until
       FROM game_matches WHERE id = $1`,
    [matchId],
  );
  assert.equal(leaseAfterStop.rows[0].battle_worker_id, null);
  assert.equal(leaseAfterStop.rows[0].battle_worker_lease_until, null);

  const remoteWorkerId = `remote-memory-smoke-${suffix}`;
  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO battle_worker_nodes (
         worker_id, node_id, public_realtime_url, lease_until
       ) VALUES ($1, 'remote-node', $2, NOW() + INTERVAL '1 minute')`,
      [remoteWorkerId, "wss://battle-2.example/api/realtime/battle"],
    );
    await client.query(
      `UPDATE game_matches
          SET battle_worker_id = $2,
              battle_worker_epoch = battle_worker_epoch + 1,
              battle_worker_lease_until = NOW() + INTERVAL '1 minute'
        WHERE id = $1`,
      [matchId, remoteWorkerId],
    );
  });
  const routedTicket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryA,
    { lifetimeSeconds: 30 },
  );
  assert.equal(
    routedTicket.websocket_url,
    "wss://battle-2.example/api/realtime/battle",
  );
  const routedAccount = await authenticateBattleRealtimeTicket(
    { headers: { "x-battle-ticket": routedTicket.ticket } },
    remoteWorkerId,
  );
  assert.equal(String(routedAccount.id), String(accountId));
  await withTransaction(async (client) => {
    await client.query(
      `UPDATE game_matches
          SET battle_worker_id = NULL,
              battle_worker_lease_until = NULL
        WHERE id = $1 AND battle_worker_id = $2`,
      [matchId, remoteWorkerId],
    );
    await client.query(
      "DELETE FROM battle_worker_nodes WHERE worker_id = $1",
      [remoteWorkerId],
    );
  });

  const recovered = await registryB.getSnapshot(accountId);
  assert.ok(recovered.state_epoch > first.state_epoch);
  assert.equal(recovered.last_processed_sequence, 2);
  await assert.rejects(
    authenticateBattleRealtimeTicket(
      { headers: { "x-battle-ticket": staleRouteTicket.ticket } },
      registryB.instanceId,
    ),
    (error) => error.code === "BATTLE_TICKET_INVALID",
  );
  const recoveredTicket = await issueBattleRealtimeTicket(
    { id: accountId, session_id: sessionId },
    registryB,
    { lifetimeSeconds: 30 },
  );
  assert.equal(recoveredTicket.state_epoch, recovered.state_epoch);
  const recoveredAccount = await authenticateBattleRealtimeTicket(
    { headers: { "x-battle-ticket": recoveredTicket.ticket } },
    registryB.instanceId,
  );
  assert.equal(String(recoveredAccount.id), String(accountId));
  const replay = await registryB.submitCommand(accountId, {
    sequence: 2,
    command: {
      type: "basic_attack",
      target_x: viewer.position_x + 100,
      target_y: viewer.position_y,
    },
  });
  assert.equal(replay.replayed, true);
  assert.equal(replay.accepted_sequence, 2);

  await registryB.stop();
  await pool.query(
    `INSERT INTO online_presence (
       account_id, session_id, lease_expires_at
     ) VALUES ($1, $2, NOW() + INTERVAL '10 minutes')
     ON CONFLICT (account_id) DO UPDATE SET
       session_id = EXCLUDED.session_id,
       lease_expires_at = EXCLUDED.lease_expires_at`,
    [accountId, sessionId],
  );
  const port = 19_000 + Number.parseInt(randomBytes(2).toString("hex"), 16) % 500;
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, ["src/server.js"], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      HOST: "127.0.0.1",
      PORT: String(port),
      BATTLE_RUNTIME_ENABLED: "true",
      BATTLE_MEMORY_WORKERS: "true",
      BATTLE_REALTIME_REQUIRE_TICKET: "true",
      BATTLE_NODE_ID: `ticket-api-${suffix}`,
      BATTLE_PUBLIC_REALTIME_URL: `ws://127.0.0.1:${port}/api/realtime/battle`,
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  const stderr = { value: "" };
  child.stderr.on("data", (chunk) => { stderr.value += chunk.toString(); });
  try {
    await waitForServer(baseUrl, child, stderr);
    const ticketResponse = await fetch(
      `${baseUrl}/api/rooms/match/battle/realtime-ticket`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${sessionToken}`,
          "Content-Type": "application/json",
        },
        body: "{}",
      },
    );
    assert.equal(ticketResponse.status, 201, stderr.value);
    const ticketPayload = await ticketResponse.json();
    assert.equal(ticketPayload.ok, true);
    assert.equal(ticketPayload.match_id, String(matchId));
    assert.equal(
      ticketPayload.websocket_url,
      `ws://127.0.0.1:${port}/api/realtime/battle`,
    );
    await connectTicketSocket(ticketPayload.websocket_url, ticketPayload.ticket);
    await assertTicketCannotBeReused(
      ticketPayload.websocket_url,
      ticketPayload.ticket,
    );
  } finally {
    if (child.exitCode == null) {
      child.kill();
      await new Promise((resolve) => child.once("exit", resolve));
    }
    await pool.query(
      "DELETE FROM battle_worker_nodes WHERE node_id = $1",
      [`ticket-api-${suffix}`],
    );
  }

  console.log("BATTLE_MEMORY_POSTGRES_OK");
} finally {
  await registryA.stop();
  await registryB.stop();
  await cleanup();
  await pool.end();
}
