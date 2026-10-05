import assert from "node:assert/strict";
import test from "node:test";

import { loadBattleMap } from "../src/battle-map-catalog.js";
import {
  firstBattleTargetOnSegment,
  processBattleWorldStep,
  worldCollisionMap,
} from "../src/battle-world.js";

test("Maya authoritative world contains every authored object exactly once", async () => {
  const map = await loadBattleMap("maya_score");
  assert.equal(map.worldBuildings.length, 45);
  assert.equal(map.worldChiefs.length, 2);
  assert.equal(map.footpointSpawners.length, 2);
  assert.equal(
    new Set(map.worldBuildings.map((value) => value.entityKey)).size,
    45,
  );
  assert.equal(
    map.worldBuildings.flatMap((value) => value.collisionRectangles).length,
    map.buildingCollisionRectangles.length,
  );
});

test("an infinite ray fraction never becomes a phantom world hit", async () => {
  const map = await loadBattleMap("maya_score");
  const projectile = {
    source_entity_key: "building:68",
    team_no: 2,
    position_x: 1192,
    position_y: 252,
  };
  const target = {
    team_no: 1,
    slot_no: 1,
    position_x: 1492,
    position_y: 252,
    dead: false,
  };
  const hit = firstBattleTargetOnSegment(
    projectile,
    [target],
    [],
    { x: 1228, y: 252 },
    map,
    { includeBuildings: false },
  );
  assert.equal(hit.target, null);
  assert.equal(hit.fraction, Infinity);
});

test("turret projectile advances over fixed steps before server damage", async () => {
  const map = await loadBattleMap("maya_score");
  const turretPlacement = map.worldBuildings.find(
    (value) => value.entityKey === "building:68",
  );
  const turret = {
    match_id: 1,
    entity_key: "building:68",
    entity_type: "building",
    template_id: 1103,
    team_no: 2,
    position_x: turretPlacement.x,
    position_y: turretPlacement.y,
    spawn_x: turretPlacement.x,
    spawn_y: turretPlacement.y,
    hit_points: 3600,
    maximum_hit_points: 3600,
    basic_attack_damage: 300,
    penetration: 0,
    physical_armor: 50,
    energy_shield: 50,
    move_speed: 0,
    attack_range: 480,
    hit_radius: 36,
    damage_type: "physical",
    attack_interval_ms: 1000,
    attack_ready_at: null,
    burst_shots: 1,
    burst_remaining: 0,
    burst_break_ms: 0,
    respawn_ms: 0,
    can_attack: true,
    is_structure: true,
    activated: true,
    dead: false,
    hits_to_destroy: 0,
    hit_count: 0,
    collision_rectangles: turretPlacement.collisionRectangles,
    attack_serial: 0,
    move_direction: 1,
    projectile_speed: 720,
    muzzle_offset: 52,
  };
  const target = {
    team_no: 1,
    slot_no: 1,
    position_x: 1492,
    position_y: 252,
    dead: false,
  };
  let damage = 0;
  const context = {
    match: { team_1_score: 0, team_2_score: 0 },
    participants: [target],
    worldEntities: [turret],
    projectiles: [],
    map: {
      ...map,
      collisionRectangles: worldCollisionMap(map, [turret]).collisionRectangles,
    },
    applyDamage: (_attacker, _target, value) => {
      damage += value;
    },
    emitEvent: () => {},
  };
  processBattleWorldStep(context, 0, 50);
  assert.equal(damage, 0);
  assert.equal(context.projectiles.length, 1);
  for (let tick = 1; tick <= 10 && damage === 0; tick += 1) {
    processBattleWorldStep(context, tick * 50, (tick + 1) * 50);
  }
  assert.equal(damage, 300);
  assert.equal(context.projectiles.length, 0);
});
