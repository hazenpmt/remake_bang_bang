import { randomUUID } from "node:crypto";

import { config } from "./config.js";
import { pool } from "./db.js";
import {
  BattleRuntimeError,
  advanceBattleMemoryState,
  applyBattleMemoryCommand,
  buildBattleMemorySnapshot,
  checkpointBattleMemoryState,
  hydrateBattleMemoryStateByAccount,
  hydrateBattleMemoryStateByMatchId,
} from "./battle-runtime.js";

const CONTINUOUS_COMMANDS = new Set(["move", "skill_aim"]);
const FINISHED_WORKER_RETENTION_MS = 120_000;

function workerError(code, message, retryAfterMs = 0) {
  const error = new BattleRuntimeError(503, code, message);
  if (retryAfterMs > 0) {
    error.retryAfterMs = retryAfterMs;
  }
  return error;
}

function enqueue(worker, operation) {
  const result = worker.tail.then(operation);
  worker.tail = result.catch(() => {});
  return result;
}

export function createBattleMemoryWorkerRegistry(options = {}) {
  const tickMs = Math.max(20, Number(options.tickMs ?? config.battleTickMs));
  const checkpointMs = Math.max(
    tickMs,
    Number(options.checkpointMs ?? config.battleCheckpointMs),
  );
  const leaseMs = Math.max(
    checkpointMs * 3,
    Number(options.leaseMs ?? config.battleWorkerLeaseMs),
  );
  const discoveryMs = Math.max(
    checkpointMs,
    Number(options.discoveryMs ?? config.battleWorkerDiscoveryMs),
  );
  const workerLimit = Math.max(
    1,
    Number(options.workerLimit ?? config.battleWorkerLimit),
  );
  const finishedRetentionMs = Math.max(
    1_000,
    Number(options.finishedRetentionMs ?? FINISHED_WORKER_RETENTION_MS),
  );
  const nodeLeaseMs = Math.max(
    5_000,
    Number(options.nodeLeaseMs ?? config.battleWorkerNodeLeaseMs),
  );
  const nodeId = String(options.nodeId ?? config.battleNodeId).slice(0, 96);
  const publicRealtimeUrl = String(
    options.publicRealtimeUrl ?? config.battlePublicRealtimeUrl,
  ) || null;
  const instanceId = String(
    options.instanceId
      ?? `${nodeId.slice(0, 40)}:${process.pid}:${randomUUID()}`,
  ).slice(0, 96);
  const workersByMatch = new Map();
  const workersByAccount = new Map();
  let hydrationTail = Promise.resolve();
  let tickTimer = null;
  let discoveryTimer = null;
  let nodeHeartbeatTimer = null;
  let discoveryRunning = false;
  let discoveryPromise = Promise.resolve();
  let nodeHeartbeatPromise = Promise.resolve();
  let stopped = false;

  function serializeHydration(operation) {
    const result = hydrationTail.then(operation);
    hydrationTail = result.catch(() => {});
    return result;
  }

  function unregister(worker) {
    const matchKey = String(worker.state.match.id);
    if (workersByMatch.get(matchKey) === worker) {
      workersByMatch.delete(matchKey);
    }
    for (const participant of worker.state.participants) {
      if (participant.is_bot || participant.account_id == null) {
        continue;
      }
      const accountKey = String(participant.account_id);
      if (workersByAccount.get(accountKey) === worker) {
        workersByAccount.delete(accountKey);
      }
    }
  }

  function retire(worker, error = null) {
    worker.retired = true;
    worker.retireError = error;
    unregister(worker);
  }

  function register(state) {
    const matchKey = String(state.match.id);
    const existing = workersByMatch.get(matchKey);
    if (existing) {
      return existing;
    }
    const worker = {
      state,
      tail: Promise.resolve(),
      tickQueued: false,
      retired: false,
      retireError: null,
      finishedAt: state.match.phase === "finished" ? Date.now() : 0,
      checkpointFailures: 0,
      nextCheckpointAttemptAt: 0,
    };
    workersByMatch.set(matchKey, worker);
    for (const participant of state.participants) {
      if (!participant.is_bot && participant.account_id != null) {
        workersByAccount.set(String(participant.account_id), worker);
      }
    }
    return worker;
  }

  function ensureRunning() {
    if (stopped) {
      throw workerError(
        "BATTLE_WORKERS_STOPPED",
        "Máy chủ trận đấu đang dừng để bảo trì.",
        1_000,
      );
    }
  }

  async function ensureByAccount(accountId) {
    ensureRunning();
    const accountKey = String(accountId);
    const existing = workersByAccount.get(accountKey);
    if (existing && !existing.retired) {
      return existing;
    }
    return serializeHydration(async () => {
      ensureRunning();
      const secondCheck = workersByAccount.get(accountKey);
      if (secondCheck && !secondCheck.retired) {
        return secondCheck;
      }
      const state = await hydrateBattleMemoryStateByAccount(
        accountId,
        instanceId,
        leaseMs,
      );
      return register(state);
    });
  }

  async function ensureByMatchId(matchId) {
    ensureRunning();
    const matchKey = String(matchId);
    const existing = workersByMatch.get(matchKey);
    if (existing && !existing.retired) {
      return existing;
    }
    return serializeHydration(async () => {
      ensureRunning();
      const secondCheck = workersByMatch.get(matchKey);
      if (secondCheck && !secondCheck.retired) {
        return secondCheck;
      }
      const state = await hydrateBattleMemoryStateByMatchId(
        matchId,
        instanceId,
        leaseMs,
      );
      return register(state);
    });
  }

  function checkpointDue(state, nowMs) {
    return nowMs - Number(state.lastCheckpointAt || 0) >= checkpointMs;
  }

  async function checkpoint(worker, options = {}) {
    try {
      const result = await checkpointBattleMemoryState(worker.state, options);
      worker.checkpointFailures = 0;
      worker.nextCheckpointAttemptAt = 0;
      return result;
    } catch (error) {
      if (error?.code === "BATTLE_WORKER_LEASE_LOST") {
        retire(worker, error);
      } else {
        worker.checkpointFailures += 1;
        worker.nextCheckpointAttemptAt = Date.now() + Math.min(
          5_000,
          100 * (2 ** Math.min(6, worker.checkpointFailures - 1)),
        );
      }
      throw error;
    }
  }

  async function getSnapshot(accountId) {
    const worker = await ensureByAccount(accountId);
    return enqueue(worker, async () => {
      if (worker.retired) {
        throw worker.retireError ?? workerError(
          "BATTLE_WORKER_RETIRED",
          "Worker trận đấu không còn hoạt động.",
          250,
        );
      }
      const now = new Date();
      if (worker.state.match.phase === "active") {
        await advanceBattleMemoryState(worker.state, now);
        if (checkpointDue(worker.state, now.getTime())) {
          await checkpoint(worker, { now });
        }
      }
      return buildBattleMemorySnapshot(worker.state, accountId, now);
    });
  }

  async function readSnapshot(accountId) {
    const worker = await ensureByAccount(accountId);
    return enqueue(worker, async () => {
      if (worker.retired) {
        throw worker.retireError ?? workerError(
          "BATTLE_WORKER_RETIRED",
          "Worker trận đấu không còn hoạt động.",
          250,
        );
      }
      return buildBattleMemorySnapshot(worker.state, accountId, new Date());
    });
  }

  async function submitCommand(accountId, body) {
    const worker = await ensureByAccount(accountId);
    return enqueue(worker, async () => {
      if (worker.retired) {
        throw worker.retireError ?? workerError(
          "BATTLE_WORKER_RETIRED",
          "Worker trận đấu không còn hoạt động.",
          250,
        );
      }
      const now = new Date();
      if (worker.state.match.phase === "active") {
        await advanceBattleMemoryState(worker.state, now);
      }
      const response = await applyBattleMemoryCommand(
        worker.state,
        accountId,
        body,
        now,
      );
      const commandType = String(body?.command?.type ?? "");
      const forceCheckpoint = (
        !CONTINUOUS_COMMANDS.has(commandType)
        || worker.state.match.phase !== "active"
      );
      if (
        forceCheckpoint
        || checkpointDue(worker.state, now.getTime())
      ) {
        await checkpoint(worker, { now });
      }
      if (!response.replayed) {
        const cached = worker.state.responseCache.get(
          `${accountId}:${response.accepted_sequence}`,
        );
        if (cached) {
          return structuredClone(cached.response);
        }
      }
      return response;
    });
  }

  function queueTick(worker, now) {
    if (worker.tickQueued || worker.retired || worker.state.released) {
      return;
    }
    worker.tickQueued = true;
    enqueue(worker, async () => {
      if (worker.retired || worker.state.released) {
        return;
      }
      await advanceBattleMemoryState(worker.state, now);
      if (
        (
          checkpointDue(worker.state, now.getTime())
          || worker.state.match.phase !== "active"
        )
        && now.getTime() >= worker.nextCheckpointAttemptAt
      ) {
        await checkpoint(worker, { now });
      }
      if (worker.state.match.phase === "finished" && worker.finishedAt === 0) {
        worker.finishedAt = now.getTime();
      }
    }).catch((error) => {
      if (error?.code === "BATTLE_WORKER_LEASE_LOST") {
        retire(worker, error);
      } else if (
        worker.checkpointFailures <= 1
        || (worker.checkpointFailures & (worker.checkpointFailures - 1)) === 0
      ) {
        console.error(
          `Battle memory tick failed for match ${worker.state.match.id}:`,
          error,
        );
      }
    }).finally(() => {
      worker.tickQueued = false;
    });
  }

  function runTick() {
    if (stopped) {
      return;
    }
    const now = new Date();
    for (const worker of workersByMatch.values()) {
      if (
        worker.finishedAt > 0
        && now.getTime() - worker.finishedAt >= finishedRetentionMs
      ) {
        retire(worker);
        continue;
      }
      queueTick(worker, now);
    }
  }

  async function discover() {
    if (stopped || discoveryRunning) {
      return;
    }
    discoveryRunning = true;
    try {
      const activeWorkerCount = [...workersByMatch.values()].filter(
        (worker) => !worker.retired && worker.state.match.phase === "active",
      ).length;
      const capacity = workerLimit - activeWorkerCount;
      if (capacity <= 0) {
        return;
      }
      const result = await pool.query(
        `SELECT id
           FROM game_matches
          WHERE phase = 'active'
            AND NOT is_test
            AND (
              battle_worker_lease_until IS NULL
              OR battle_worker_lease_until <= NOW()
              OR battle_worker_id = $2
            )
          ORDER BY battle_simulated_at NULLS FIRST, id
          LIMIT $1`,
        [capacity, instanceId],
      );
      for (const row of result.rows) {
        if (stopped) {
          break;
        }
        try {
          await ensureByMatchId(row.id);
        } catch (error) {
          if (!["BATTLE_WORKER_BUSY", "BATTLE_NOT_FOUND"].includes(error?.code)) {
            console.error(`Battle memory discovery failed for match ${row.id}:`, error);
          }
        }
      }
    } finally {
      discoveryRunning = false;
    }
  }

  function scheduleDiscovery() {
    if (stopped || discoveryRunning) {
      return discoveryPromise;
    }
    discoveryPromise = discover().catch((error) => {
      console.error("Battle memory discovery failed:", error);
    });
    return discoveryPromise;
  }

  function scheduleNodeHeartbeat() {
    if (stopped) {
      return nodeHeartbeatPromise;
    }
    nodeHeartbeatPromise = nodeHeartbeatPromise.then(() => pool.query(
      `INSERT INTO battle_worker_nodes (
         worker_id, node_id, public_realtime_url, lease_until
       ) VALUES ($1, $2, $3, NOW() + ($4::bigint * INTERVAL '1 millisecond'))
       ON CONFLICT (worker_id) DO UPDATE SET
         node_id = EXCLUDED.node_id,
         public_realtime_url = EXCLUDED.public_realtime_url,
         lease_until = EXCLUDED.lease_until,
         updated_at = NOW()`,
      [instanceId, nodeId, publicRealtimeUrl, nodeLeaseMs],
    )).catch((error) => {
      console.error("Battle worker node heartbeat failed:", error);
    });
    return nodeHeartbeatPromise;
  }

  function start() {
    if (stopped || tickTimer || discoveryTimer) {
      return;
    }
    tickTimer = setInterval(runTick, tickMs);
    tickTimer.unref();
    discoveryTimer = setInterval(scheduleDiscovery, discoveryMs);
    discoveryTimer.unref();
    nodeHeartbeatTimer = setInterval(
      scheduleNodeHeartbeat,
      Math.max(1_000, Math.floor(nodeLeaseMs / 3)),
    );
    nodeHeartbeatTimer.unref();
    scheduleNodeHeartbeat();
    scheduleDiscovery();
  }

  async function stop() {
    if (stopped) {
      return;
    }
    stopped = true;
    if (tickTimer) {
      clearInterval(tickTimer);
      tickTimer = null;
    }
    if (discoveryTimer) {
      clearInterval(discoveryTimer);
      discoveryTimer = null;
    }
    if (nodeHeartbeatTimer) {
      clearInterval(nodeHeartbeatTimer);
      nodeHeartbeatTimer = null;
    }
    await discoveryPromise;
    await nodeHeartbeatPromise;
    await hydrationTail.catch(() => {});
    const workers = [...workersByMatch.values()];
    const results = await Promise.allSettled(workers.map((worker) => enqueue(worker, async () => {
      if (!worker.retired && !worker.state.released) {
        await checkpoint(worker, { now: new Date(), release: true });
      }
      unregister(worker);
    })));
    for (const result of results) {
      if (result.status === "rejected") {
        console.error("Battle memory shutdown checkpoint failed:", result.reason);
      }
    }
    await pool.query(
      "DELETE FROM battle_worker_nodes WHERE worker_id = $1",
      [instanceId],
    ).catch((error) => {
      console.error("Battle worker node unregister failed:", error);
    });
  }

  function stats() {
    const workers = [...workersByMatch.values()];
    return {
      instance_id: instanceId,
      node_id: nodeId,
      public_realtime_url: publicRealtimeUrl,
      workers: workers.length,
      active_workers: workers.filter(
        (worker) => !worker.retired && worker.state.match.phase === "active",
      ).length,
      finished_workers: workers.filter(
        (worker) => !worker.retired && worker.state.match.phase === "finished",
      ).length,
      accounts: workersByAccount.size,
    };
  }

  return Object.freeze({
    instanceId,
    getSnapshot,
    readSnapshot,
    submitCommand,
    start,
    stop,
    stats,
    ensureByMatchId,
    checkpointMatch(matchId, checkpointOptions = {}) {
      const worker = workersByMatch.get(String(matchId));
      if (!worker) {
        throw workerError(
          "BATTLE_WORKER_NOT_LOADED",
          "Trận đấu chưa được nạp vào worker này.",
        );
      }
      return enqueue(worker, () => checkpoint(worker, checkpointOptions));
    },
  });
}
