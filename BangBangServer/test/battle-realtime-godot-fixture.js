import { createServer } from "node:http";

import { attachBattleRealtime } from "../src/battle-realtime.js";

const port = Number.parseInt(process.env.BATTLE_REALTIME_TEST_PORT ?? "18991", 10);
let revision = 12;
let lastSequence = 0;
let connectionCount = 0;
let playerX = 10;
const staticState = "fixture-static-state-".repeat(128);

function snapshot() {
  return {
    protocol_version: 2,
    match_id: "fixture-match",
    state_epoch: 7,
    revision,
    last_processed_sequence: lastSequence,
    static_state: staticState,
    entities: [{
      team_no: 1,
      slot_no: 1,
      x: playerX,
      y: 20,
      hit_points: 100,
    }],
    world_entities: [{
      entity_key: "building:46",
      hit_points: 500,
    }],
  };
}

const server = createServer((_request, response) => {
  response.writeHead(404);
  response.end();
});

const realtime = attachBattleRealtime(server, {
  snapshotMs: 50,
  heartbeatMs: 1_000,
  authenticate: async (request) => {
    if (!/^godot-live-ticket-\d+$/.test(request.headers["x-battle-ticket"] ?? "")) {
      const error = new Error("Unauthorized");
      error.status = 401;
      throw error;
    }
    connectionCount += 1;
    if (connectionCount === 1) {
      setTimeout(() => {
        realtime.revokeSession(901);
      }, 250).unref();
    }
    return { id: 501, session_id: 901, username: "godot-live" };
  },
  initialSnapshot: async () => snapshot(),
  readSnapshot: async () => snapshot(),
  submitCommand: async (_accountId, body) => {
    lastSequence = body.sequence;
    revision += 1;
    playerX += 2;
    return {
      accepted_sequence: body.sequence,
      replayed: false,
      snapshot: snapshot(),
    };
  },
});

server.listen(port, "127.0.0.1", () => {
  console.log(`BATTLE_REALTIME_GODOT_FIXTURE_READY ${port}`);
});

async function shutdown() {
  await realtime.close();
  server.close(() => process.exit(0));
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
