import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import WebSocket from "ws";

import {
  applyBattleSnapshotDelta,
  attachBattleRealtime,
  buildBattleSnapshotDelta,
  validateBattleRealtimeMessage,
} from "../src/battle-realtime.js";

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server.address().port));
  });
}

function closeServer(server) {
  return new Promise((resolve) => server.close(() => resolve()));
}

function openClient(url, headers = {}) {
  const socket = new WebSocket(url, { headers, perMessageDeflate: false });
  const messages = [];
  const waiters = [];
  socket.on("message", (data) => {
    const value = JSON.parse(data.toString("utf8"));
    messages.push(value);
    for (let index = waiters.length - 1; index >= 0; index -= 1) {
      if (waiters[index].predicate(value)) {
        const [{ resolve }] = waiters.splice(index, 1);
        resolve(value);
      }
    }
  });
  const opened = new Promise((resolve, reject) => {
    socket.once("open", resolve);
    socket.once("error", reject);
  });
  function next(predicate, timeoutMs = 2_000) {
    const existing = messages.find(predicate);
    if (existing) {
      return Promise.resolve(existing);
    }
    return new Promise((resolve, reject) => {
      const waiter = { predicate, resolve };
      waiters.push(waiter);
      const timer = setTimeout(() => {
        const index = waiters.indexOf(waiter);
        if (index >= 0) {
          waiters.splice(index, 1);
        }
        reject(new Error("Timed out waiting for realtime message."));
      }, timeoutMs);
      timer.unref();
      waiter.resolve = (value) => {
        clearTimeout(timer);
        resolve(value);
      };
    });
  }
  return { socket, opened, next };
}

test("battle realtime accepts only bounded protocol messages", () => {
  assert.deepEqual(
    validateBattleRealtimeMessage({
      type: "command",
      request_id: 7,
      sequence: 3,
      command: { type: "move", x: 1, y: 0 },
    }),
    {
      type: "command",
      requestId: 7,
      body: { sequence: 3, command: { type: "move", x: 1, y: 0 } },
    },
  );
  assert.throws(
    () => validateBattleRealtimeMessage({
      type: "command",
      request_id: 7,
      sequence: 3,
      command: { type: "move" },
      damage: 999_999,
    }),
    /unsupported fields/,
  );
  assert.throws(
    () => validateBattleRealtimeMessage({ type: "unknown" }),
    /not supported/,
  );
});

test("battle realtime delta reconstructs the exact next snapshot", () => {
  const previous = {
    protocol_version: 2,
    match_id: "9",
    state_epoch: 4,
    revision: 17,
    result: null,
    transient_notice: "old",
    entities: [{
      team_no: 1,
      slot_no: 1,
      x: 10,
      y: 20,
      hit_points: 100,
      cooldowns: { primary: 0 },
    }],
    world_entities: [{
      entity_key: "building:46",
      hit_points: 500,
      active: true,
    }],
  };
  const current = {
    protocol_version: 2,
    match_id: "9",
    state_epoch: 4,
    revision: 18,
    result: { winner_team_no: 1 },
    entities: [{
      team_no: 1,
      slot_no: 1,
      x: 12,
      y: 20,
      hit_points: 91,
      cooldowns: { primary: 450 },
    }],
    world_entities: [{
      entity_key: "building:46",
      hit_points: 470,
      active: true,
    }],
  };
  const delta = buildBattleSnapshotDelta(previous, current);
  assert.ok(delta);
  assert.deepEqual(applyBattleSnapshotDelta(previous, delta), current);
  assert.equal(previous.revision, 17);
  assert.equal(previous.entities[0].hit_points, 100);

  assert.equal(buildBattleSnapshotDelta(previous, {
    ...current,
    state_epoch: 5,
  }), null);
  assert.equal(buildBattleSnapshotDelta(previous, {
    ...current,
    entities: [...current.entities, { team_no: 2, slot_no: 1 }],
  }), null);
});

test("battle realtime authenticates, pushes snapshots, sequences commands and replaces stale sockets", async () => {
  const server = createServer((_request, response) => {
    response.writeHead(404);
    response.end();
  });
  let revision = 4;
  const submitted = [];
  const staticState = "x".repeat(2_048);
  const realtime = attachBattleRealtime(server, {
    snapshotMs: 50,
    heartbeatMs: 5_000,
    authenticate: async (request) => {
      if (request.headers.authorization !== "Bearer valid-test-token") {
        const error = new Error("Unauthorized");
        error.status = 401;
        throw error;
      }
      return { id: 42, session_id: 77, username: "tester" };
    },
    initialSnapshot: async () => ({
      protocol_version: 2,
      match_id: "9",
      revision,
      last_processed_sequence: submitted.length,
      state_epoch: 1,
      static_state: staticState,
      entities: [],
      world_entities: [],
    }),
    readSnapshot: async () => ({
      protocol_version: 2,
      match_id: "9",
      revision,
      last_processed_sequence: submitted.length,
      state_epoch: 1,
      static_state: staticState,
      entities: [],
      world_entities: [],
    }),
    submitCommand: async (accountId, body) => {
      assert.equal(accountId, 42);
      submitted.push(body);
      revision += 1;
      return {
        accepted_sequence: body.sequence,
        replayed: false,
        snapshot: {
          protocol_version: 2,
          match_id: "9",
          revision,
          last_processed_sequence: body.sequence,
          state_epoch: 1,
          static_state: staticState,
          entities: [],
          world_entities: [],
        },
      };
    },
  });
  const port = await listen(server);
  const url = `ws://127.0.0.1:${port}/api/realtime/battle`;

  const unauthorizedStatus = await new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    socket.once("unexpected-response", (_request, response) => {
      resolve(response.statusCode);
      response.resume();
    });
    socket.once("error", (error) => {
      if (!String(error.message).includes("Unexpected server response")) {
        reject(error);
      }
    });
  });
  assert.equal(unauthorizedStatus, 401);

  const first = openClient(url, { Authorization: "Bearer valid-test-token" });
  await first.opened;
  const hello = await first.next((value) => value.type === "hello");
  assert.equal(hello.protocol_version, 2);
  assert.equal(hello.transport_version, 3);
  const initial = await first.next((value) => value.type === "snapshot");
  assert.equal(initial.snapshot_serial, 1);
  assert.equal(initial.snapshot.revision, 4);

  first.socket.send(JSON.stringify({
    type: "command",
    request_id: 11,
    sequence: 1,
    command: { type: "move", x: 1, y: 0 },
  }));
  const command = await first.next(
    (value) => value.type === "command_result" && value.request_id === 11,
  );
  assert.equal(command.ok, true);
  assert.equal(command.accepted_sequence, 1);
  assert.equal(command.snapshot.revision, 5);
  assert.equal(submitted.length, 1);
  const delta = await first.next((value) => value.type === "snapshot_delta");
  assert.equal(delta.base_snapshot_serial, 1);
  assert.equal(delta.snapshot_serial, 2);
  assert.equal(delta.base_revision, 4);
  assert.equal(delta.revision, 5);
  assert.equal(delta.delta.set.revision, 5);

  const replaced = new Promise((resolve) => {
    first.socket.once("close", (code) => resolve(code));
  });
  const second = openClient(url, { Authorization: "Bearer valid-test-token" });
  await second.opened;
  assert.equal(await replaced, 4001);
  assert.equal(realtime.connectionCount(), 1);
  await second.next((value) => value.type === "snapshot");

  const revoked = new Promise((resolve) => {
    second.socket.once("close", (code) => resolve(code));
  });
  realtime.revokeSession(77);
  assert.equal(await revoked, 4003);

  await realtime.close();
  await closeServer(server);
});
