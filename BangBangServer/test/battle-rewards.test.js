import assert from "node:assert/strict";
import test from "node:test";

import { calculateBattleReward } from "../src/battle-rewards.js";

test("battle rewards use only authoritative KDA and winner team", () => {
  const participant = { team_no: 1, kills: 2, deaths: 1, assists: 3 };
  assert.deepEqual(calculateBattleReward(participant, 1), {
    outcome: "win",
    experience: 110,
    silver: 17,
  });
  assert.deepEqual(calculateBattleReward(participant, 2), {
    outcome: "lose",
    experience: 85,
    silver: 17,
  });
  assert.deepEqual(calculateBattleReward(participant, 0), {
    outcome: "draw",
    experience: 85,
    silver: 17,
  });
});

test("battle reward never grants negative currency", () => {
  assert.deepEqual(calculateBattleReward({
    team_no: 2,
    kills: 0,
    deaths: 99,
    assists: 0,
  }, 1), {
    outcome: "lose",
    experience: 50,
    silver: 0,
  });
});
