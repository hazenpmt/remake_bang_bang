import assert from "node:assert/strict";
import test from "node:test";

import { loadBattleMap } from "../src/battle-map-catalog.js";
import {
  battleCommandHash,
  calculateBattleDamage,
  firstEnemyOnSegment,
  moveTankWithCollision,
  validateBattleCommandRequest,
} from "../src/battle-policy.js";

test("authoritative map uses the original bounds, spawns, and collision", async () => {
  const map = await loadBattleMap("random");
  assert.equal(map.width, 2160);
  assert.equal(map.height, 1413);
  assert.deepEqual(map.spawnBySlot.get("1:1"), {
    team: 1,
    slot: 1,
    x: 204,
    y: 468,
  });
  assert.equal(map.collisionRectangles.length, 68);

  const stopped = moveTankWithCollision(
    { x: 204, y: 468 },
    { x: -200, y: 0 },
    map,
  );
  // The authored left boundary ends at x=72 and the tank radius is 36.
  assert.ok(stopped.x >= 108 - 0.1, `unexpected wall crossing: ${stopped.x}`);
});

test("authoritative collision preserves wall sliding without tunnelling", () => {
  const map = {
    width: 200,
    height: 200,
    tankCollisionCenterOffset: { x: 0, y: 0 },
    tankCollisionRadius: 1,
    collisionRectangles: [{ x: 5, y: 0, width: 2, height: 100 }],
  };
  const result = moveTankWithCollision(
    { x: 2, y: 10 },
    { x: 10, y: 10 },
    map,
  );
  assert.ok(result.x <= 4.001, `unexpected wall crossing: ${result.x}`);
  assert.ok(result.y > 19.9, `expected wall slide, got y=${result.y}`);
});

test("battle command validation normalizes movement and rejects invalid numbers", () => {
  const result = validateBattleCommandRequest({
    sequence: 7,
    command: { type: "move", x: 4, y: 3 },
  });
  assert.equal(result.sequence, 7);
  assert.ok(Math.abs(result.command.x - 0.8) < 0.000001);
  assert.ok(Math.abs(result.command.y - 0.6) < 0.000001);
  assert.throws(
    () => validateBattleCommandRequest({
      sequence: 8,
      command: { type: "basic_attack", target_x: Infinity, target_y: 2 },
    }),
    /finite/,
  );
});

test("canonical command hash is stable but changes when a replay payload changes", () => {
  assert.equal(
    battleCommandHash({ type: "move", x: 1, y: 0 }),
    battleCommandHash({ y: 0, x: 1, type: "move" }),
  );
  assert.notEqual(
    battleCommandHash({ type: "move", x: 1, y: 0 }),
    battleCommandHash({ type: "move", x: 0, y: 1 }),
  );
});

test("server ray chooses the first enemy before terrain", async () => {
  const map = await loadBattleMap("random");
  const attacker = { team_no: 1, position_x: 800, position_y: 800, dead: false };
  const near = { team_no: 2, position_x: 900, position_y: 800, dead: false };
  const far = { team_no: 2, position_x: 980, position_y: 800, dead: false };
  const hit = firstEnemyOnSegment(
    attacker,
    [attacker, far, near],
    { x: 1050, y: 800 },
    map,
  );
  assert.equal(hit.target, near);
});

test("damage, armour, penetration, and critical roll are server calculated", () => {
  const attacker = {
    damage_type: "physical",
    penetration: 30,
    critical_chance_basis_points: 500,
    critical_damage_basis_points: 15000,
  };
  const target = { physical_armor: 150, energy_shield: 150 };
  assert.deepEqual(calculateBattleDamage(attacker, target, 238, 9999), {
    critical: false,
    damage: 213,
  });
  assert.deepEqual(calculateBattleDamage(attacker, target, 238, 0), {
    critical: true,
    damage: 319,
  });
});
