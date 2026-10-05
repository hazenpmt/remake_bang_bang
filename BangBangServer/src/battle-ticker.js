import { config } from "./config.js";
import { pool } from "./db.js";
import { advanceBattleMatch } from "./battle-runtime.js";

async function activeBattleIds(limit) {
  const result = await pool.query(
    `SELECT id
      FROM game_matches
      WHERE phase = 'active' AND NOT is_test
      ORDER BY battle_simulated_at NULLS FIRST, id
      LIMIT $1`,
    [limit],
  );
  return result.rows.map((row) => row.id);
}

export async function advanceActiveBattleBatch(options = {}) {
  const limit = Math.max(
    1,
    Number(options.limit ?? config.battleTickBatchSize),
  );
  const concurrency = Math.max(
    1,
    Math.min(limit, Number(options.concurrency ?? config.battleTickConcurrency)),
  );
  const ids = await activeBattleIds(limit);
  let cursor = 0;
  const failures = [];
  async function worker() {
    while (cursor < ids.length) {
      const index = cursor;
      cursor += 1;
      try {
        await advanceBattleMatch(ids[index], new Date());
      } catch (error) {
        failures.push({ matchId: String(ids[index]), error });
      }
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, ids.length) }, () => worker()),
  );
  return { processed: ids.length - failures.length, failures };
}

export function startBattleTicker(options = {}) {
  const tickMs = Math.max(20, Number(options.tickMs ?? config.battleTickMs));
  let stopped = false;
  let running = false;
  let activeTick = Promise.resolve();
  const runTick = async () => {
    if (stopped || running) {
      return;
    }
    running = true;
    try {
      const result = await advanceActiveBattleBatch(options);
      for (const failure of result.failures) {
        console.error(
          `Battle tick failed for match ${failure.matchId}:`,
          failure.error,
        );
      }
    } catch (error) {
      console.error("Battle ticker failed:", error);
    } finally {
      running = false;
    }
  };
  const tick = () => {
    activeTick = runTick();
  };
  const timer = setInterval(tick, tickMs);
  timer.unref();
  tick();
  return async () => {
    stopped = true;
    clearInterval(timer);
    await activeTick;
  };
}
