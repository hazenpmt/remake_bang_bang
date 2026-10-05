import {
  FOOTPOINT_WORLD_TEMPLATE,
  CHIEF_WORLD_TEMPLATE,
  getBattleBuildingTemplate,
} from "./battle-world-catalog.js";
import {
  moveTankWithCollision,
  normalizeVector,
  segmentCircleFraction,
  segmentRectangleFraction,
  firstTerrainFraction,
} from "./battle-policy.js";

const FOOTPOINT_ROAM_PADDING = 36;
const FOOTPOINT_WANDER_RESELECT_MS = 2000;

function number(value, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function dateMs(value) {
  if (!value) {
    return 0;
  }
  const result = new Date(value).getTime();
  return Number.isFinite(result) ? result : 0;
}

function iso(value) {
  return new Date(value).toISOString();
}

export function battleEntityKey(value) {
  if (value?.entity_key) {
    return String(value.entity_key);
  }
  if (value?.source_entity_key) {
    return String(value.source_entity_key);
  }
  return `participant:${Number(value?.team_no)}:${Number(value?.slot_no)}`;
}

export function isWorldEntity(value) {
  return typeof value?.entity_key === "string";
}

function rowTemplate(row) {
  if (row.entity_type === "chief") {
    return CHIEF_WORLD_TEMPLATE;
  }
  if (row.entity_type === "footpoint") {
    return FOOTPOINT_WORLD_TEMPLATE;
  }
  return getBattleBuildingTemplate(row.template_id);
}

function hydrateWorldRow(row) {
  const template = rowTemplate(row);
  return {
    ...row,
    team_no: Number(row.team_no),
    position_x: number(row.position_x),
    position_y: number(row.position_y),
    spawn_x: number(row.spawn_x),
    spawn_y: number(row.spawn_y),
    patrol_left_x: row.patrol_left_x == null ? null : number(row.patrol_left_x),
    patrol_right_x: row.patrol_right_x == null ? null : number(row.patrol_right_x),
    initial_direction: Number(row.initial_direction),
    move_direction: Number(row.move_direction),
    hit_points: Number(row.hit_points),
    maximum_hit_points: Number(row.maximum_hit_points),
    basic_attack_damage: number(row.basic_attack_damage),
    penetration: number(row.penetration),
    physical_armor: number(row.physical_armor),
    energy_shield: number(row.energy_shield),
    move_speed: number(row.move_speed),
    attack_range: number(row.attack_range),
    hit_radius: number(row.hit_radius, 36),
    attack_interval_ms: Number(row.attack_interval_ms),
    burst_shots: Number(row.burst_shots),
    burst_remaining: Number(row.burst_remaining),
    burst_break_ms: Number(row.burst_break_ms),
    respawn_ms: Number(row.respawn_ms),
    hits_to_destroy: Number(row.hits_to_destroy),
    hit_count: Number(row.hit_count),
    attack_serial: Number(row.attack_serial),
    wander_sequence: Number(row.wander_sequence),
    collision_rectangles: Array.isArray(row.collision_rectangles)
      ? row.collision_rectangles
      : [],
    critical_chance_basis_points: 0,
    critical_damage_basis_points: 10_000,
    projectile_speed: number(template?.projectileSpeed),
    muzzle_offset: number(template?.muzzleOffset),
    contact_radius: number(template?.contactRadius),
    explosion_radius: number(template?.explosionRadius),
    explosion_damage: number(template?.explosionDamage),
    birth_ms: Number(template?.birthMs ?? 0),
  };
}

async function insertWorldEntity(client, matchId, values) {
  await client.query(
    `INSERT INTO game_match_battle_world_entities (
       match_id, entity_key, entity_type, template_id, spawner_building_id,
       team_no, position_x, position_y, spawn_x, spawn_y,
       patrol_left_x, patrol_right_x, initial_direction, move_direction,
       hit_points, maximum_hit_points,
       basic_attack_damage, penetration, physical_armor, energy_shield,
       move_speed, attack_range, hit_radius, damage_type,
       attack_interval_ms, burst_shots, burst_break_ms, respawn_ms,
       can_attack, is_structure, activated, active_at, dead,
       hits_to_destroy, collision_rectangles
     ) VALUES (
       $1, $2, $3, $4, $5,
       $6, $7, $8, $7, $8,
       $9, $10, $11, $11,
       $12, $13,
       $14, $15, $16, $17,
       $18, $19, $20, 'physical',
       $21, $22, $23, $24,
       $25, $26, $27, $28, $29,
       $30, $31::jsonb
     )`,
    [
      matchId,
      values.entityKey,
      values.entityType,
      values.templateId ?? null,
      values.spawnerBuildingId ?? null,
      values.teamNo,
      values.x,
      values.y,
      values.patrolLeftX ?? null,
      values.patrolRightX ?? null,
      values.initialDirection ?? 1,
      values.hitPoints,
      values.maximumHitPoints,
      values.basicAttackDamage ?? 0,
      values.penetration ?? 0,
      values.physicalArmor ?? 0,
      values.energyShield ?? 0,
      values.moveSpeed ?? 0,
      values.attackRange ?? 0,
      values.hitRadius ?? 36,
      values.attackIntervalMs ?? 1000,
      values.burstShots ?? 1,
      values.burstBreakMs ?? 0,
      values.respawnMs ?? 0,
      values.canAttack === true,
      values.isStructure === true,
      values.activated !== false,
      values.activeAt ?? null,
      values.dead === true,
      values.hitsToDestroy ?? 0,
      JSON.stringify(values.collisionRectangles ?? []),
    ],
  );
}

export async function ensureBattleWorldInitialized(client, match, map) {
  const result = await client.query(
    "SELECT COUNT(*)::int AS count FROM game_match_battle_world_entities WHERE match_id = $1",
    [match.id],
  );
  if (result.rows[0].count > 0) {
    return false;
  }
  for (const building of map.worldBuildings) {
    const template = getBattleBuildingTemplate(building.templateId);
    await insertWorldEntity(client, match.id, {
      entityKey: building.entityKey,
      entityType: "building",
      templateId: building.templateId,
      teamNo: building.teamNo,
      x: building.x,
      y: building.y,
      hitPoints: template.maximumHitPoints,
      maximumHitPoints: template.maximumHitPoints,
      basicAttackDamage: template.basicAttackDamage,
      penetration: template.penetration,
      physicalArmor: template.physicalArmor,
      energyShield: template.energyShield,
      attackRange: template.attackRange,
      attackIntervalMs: template.attackIntervalMs,
      canAttack: template.canAttack,
      isStructure: template.isStructure,
      hitsToDestroy: template.hitsToDestroy,
      collisionRectangles: building.collisionRectangles,
    });
  }
  for (const chief of map.worldChiefs) {
    await insertWorldEntity(client, match.id, {
      entityKey: chief.entityKey,
      entityType: "chief",
      teamNo: chief.teamNo,
      x: chief.x,
      y: chief.y,
      patrolLeftX: chief.patrolLeftX,
      patrolRightX: chief.patrolRightX,
      initialDirection: chief.initialDirection,
      hitPoints: CHIEF_WORLD_TEMPLATE.maximumHitPoints,
      maximumHitPoints: CHIEF_WORLD_TEMPLATE.maximumHitPoints,
      basicAttackDamage: CHIEF_WORLD_TEMPLATE.basicAttackDamage,
      penetration: CHIEF_WORLD_TEMPLATE.penetration,
      physicalArmor: CHIEF_WORLD_TEMPLATE.physicalArmor,
      energyShield: CHIEF_WORLD_TEMPLATE.energyShield,
      moveSpeed: CHIEF_WORLD_TEMPLATE.moveSpeed,
      attackRange: CHIEF_WORLD_TEMPLATE.attackRange,
      hitRadius: CHIEF_WORLD_TEMPLATE.hitRadius,
      attackIntervalMs: CHIEF_WORLD_TEMPLATE.attackIntervalMs,
      burstShots: CHIEF_WORLD_TEMPLATE.burstShots,
      burstBreakMs: CHIEF_WORLD_TEMPLATE.burstBreakMs,
      respawnMs: CHIEF_WORLD_TEMPLATE.respawnMs,
      canAttack: true,
    });
  }
  for (const spawner of map.footpointSpawners) {
    await insertWorldEntity(client, match.id, {
      entityKey: spawner.entityKey,
      entityType: "footpoint",
      spawnerBuildingId: spawner.buildingId,
      teamNo: 0,
      x: spawner.x,
      y: spawner.y,
      hitPoints: 0,
      maximumHitPoints: FOOTPOINT_WORLD_TEMPLATE.maximumHitPoints,
      basicAttackDamage: FOOTPOINT_WORLD_TEMPLATE.basicAttackDamage,
      penetration: FOOTPOINT_WORLD_TEMPLATE.penetration,
      physicalArmor: FOOTPOINT_WORLD_TEMPLATE.physicalArmor,
      energyShield: FOOTPOINT_WORLD_TEMPLATE.energyShield,
      moveSpeed: FOOTPOINT_WORLD_TEMPLATE.moveSpeed,
      attackRange: FOOTPOINT_WORLD_TEMPLATE.attackRange,
      hitRadius: FOOTPOINT_WORLD_TEMPLATE.hitRadius,
      respawnMs: FOOTPOINT_WORLD_TEMPLATE.respawnMs,
      activated: false,
      dead: true,
    });
  }
  return true;
}

export async function loadBattleWorldForUpdate(client, matchId) {
  const result = await client.query(
    `SELECT *
       FROM game_match_battle_world_entities
      WHERE match_id = $1
      ORDER BY entity_type, entity_key
      FOR UPDATE`,
    [matchId],
  );
  return result.rows.map(hydrateWorldRow);
}

export async function loadBattleWorldProjectilesForUpdate(client, matchId) {
  const result = await client.query(
    `SELECT *
       FROM game_match_battle_world_projectiles
      WHERE match_id = $1
      ORDER BY id
      FOR UPDATE`,
    [matchId],
  );
  return result.rows.map((row) => ({
    ...row,
    source_team_no: Number(row.source_team_no),
    team_no: Number(row.source_team_no),
    position_x: number(row.position_x),
    position_y: number(row.position_y),
    direction_x: number(row.direction_x),
    direction_y: number(row.direction_y),
    speed: number(row.speed),
    remaining_distance: number(row.remaining_distance),
    damage: number(row.damage),
    penetration: number(row.penetration),
    critical_chance_basis_points: 0,
    critical_damage_basis_points: 10_000,
  }));
}

export async function persistBattleWorld(client, entities) {
  if (entities.length === 0) {
    return;
  }
  const matchId = entities[0].match_id;
  if (entities.some((entity) => String(entity.match_id) !== String(matchId))) {
    throw new Error("Cannot persist battle world entities from different matches in one batch.");
  }
  const state = entities.map((entity) => ({
    entity_key: entity.entity_key,
    position_x: number(entity.position_x),
    position_y: number(entity.position_y),
    move_direction: Number(entity.move_direction) >= 0 ? 1 : -1,
    hit_points: Number(entity.hit_points),
    attack_ready_at: entity.attack_ready_at ?? null,
    burst_remaining: Number(entity.burst_remaining),
    burst_ready_at: entity.burst_ready_at ?? null,
    activated: entity.activated === true,
    active_at: entity.active_at ?? null,
    dead: entity.dead === true,
    respawn_at: entity.respawn_at ?? null,
    slow_until: entity.slow_until ?? null,
    slow_factor: number(entity.slow_factor),
    airstrike_marker_until: entity.airstrike_marker_until ?? null,
    stun_until: entity.stun_until ?? null,
    hit_count: Number(entity.hit_count),
    attack_serial: Number(entity.attack_serial),
    last_target_key: entity.last_target_key ?? null,
    wander_target_x: entity.wander_target_x ?? null,
    wander_target_y: entity.wander_target_y ?? null,
    wander_ready_at: entity.wander_ready_at ?? null,
    wander_sequence: Number(entity.wander_sequence),
  }));
  const result = await client.query(
    `WITH state AS (
       SELECT *
         FROM jsonb_to_recordset($2::jsonb) AS value(
           entity_key varchar(64),
           position_x numeric, position_y numeric, move_direction smallint,
           hit_points integer, attack_ready_at timestamptz,
           burst_remaining smallint, burst_ready_at timestamptz,
           activated boolean, active_at timestamptz,
           dead boolean, respawn_at timestamptz,
           slow_until timestamptz, slow_factor numeric,
           airstrike_marker_until timestamptz, stun_until timestamptz,
           hit_count integer, attack_serial bigint,
           last_target_key varchar(64),
           wander_target_x numeric, wander_target_y numeric,
           wander_ready_at timestamptz, wander_sequence bigint
         )
     )
     UPDATE game_match_battle_world_entities AS entity
        SET position_x = state.position_x,
            position_y = state.position_y,
            move_direction = state.move_direction,
            hit_points = state.hit_points,
            attack_ready_at = state.attack_ready_at,
            burst_remaining = state.burst_remaining,
            burst_ready_at = state.burst_ready_at,
            activated = state.activated,
            active_at = state.active_at,
            dead = state.dead,
            respawn_at = state.respawn_at,
            slow_until = state.slow_until,
            slow_factor = state.slow_factor,
            airstrike_marker_until = state.airstrike_marker_until,
            stun_until = state.stun_until,
            hit_count = state.hit_count,
            attack_serial = state.attack_serial,
            last_target_key = state.last_target_key,
            wander_target_x = state.wander_target_x,
            wander_target_y = state.wander_target_y,
            wander_ready_at = state.wander_ready_at,
            wander_sequence = state.wander_sequence,
            updated_at = NOW()
       FROM state
      WHERE entity.match_id = $1
        AND entity.entity_key = state.entity_key`,
    [matchId, JSON.stringify(state)],
  );
  if (result.rowCount !== entities.length) {
    throw new Error(
      `Persisted ${result.rowCount} of ${entities.length} battle world entities for match ${matchId}.`,
    );
  }
}

export async function persistBattleWorldProjectiles(client, matchId, projectiles) {
  await client.query(
    "DELETE FROM game_match_battle_world_projectiles WHERE match_id = $1",
    [matchId],
  );
  if (projectiles.length === 0) {
    return;
  }
  const state = projectiles.map((projectile) => ({
    source_entity_key: projectile.source_entity_key,
    source_team_no: Number(projectile.source_team_no),
    projectile_type: projectile.projectile_type,
    position_x: number(projectile.position_x),
    position_y: number(projectile.position_y),
    direction_x: number(projectile.direction_x),
    direction_y: number(projectile.direction_y),
    speed: number(projectile.speed),
    remaining_distance: number(projectile.remaining_distance),
    damage: number(projectile.damage),
    penetration: number(projectile.penetration),
    damage_type: projectile.damage_type,
  }));
  const result = await client.query(
    `INSERT INTO game_match_battle_world_projectiles (
       match_id, source_entity_key, source_team_no, projectile_type,
       position_x, position_y, direction_x, direction_y,
       speed, remaining_distance, damage, penetration, damage_type
     )
     SELECT $1, source_entity_key, source_team_no, projectile_type,
            position_x, position_y, direction_x, direction_y,
            speed, remaining_distance, damage, penetration, damage_type
       FROM jsonb_to_recordset($2::jsonb) AS projectile(
         source_entity_key varchar(64), source_team_no smallint,
         projectile_type varchar(16),
         position_x numeric, position_y numeric,
         direction_x numeric, direction_y numeric,
         speed numeric, remaining_distance numeric,
         damage numeric, penetration numeric, damage_type varchar(16)
       )`,
    [matchId, JSON.stringify(state)],
  );
  if (result.rowCount !== projectiles.length) {
    throw new Error(
      `Persisted ${result.rowCount} of ${projectiles.length} battle world projectiles for match ${matchId}.`,
    );
  }
}

export function worldCollisionMap(map, entities) {
  const liveBuildingCollision = entities.flatMap((entity) => (
    entity.entity_type === "building" && !entity.dead && entity.activated
      ? entity.collision_rectangles
      : []
  ));
  return {
    ...map,
    collisionRectangles: [
      ...map.staticCollisionRectangles,
      ...liveBuildingCollision,
    ],
  };
}

function combatantHitFraction(start, finish, target) {
  if (target.entity_type === "building") {
    return target.collision_rectangles.reduce(
      (best, rectangle) => Math.min(
        best,
        segmentRectangleFraction(start, finish, rectangle),
      ),
      Infinity,
    );
  }
  return segmentCircleFraction(start, finish, {
    x: number(target.position_x),
    y: number(target.position_y),
  }, number(target.hit_radius, 36));
}

export function firstBattleTargetOnSegment(
  attacker,
  participants,
  worldEntities,
  finish,
  map,
  options = {},
) {
  const includeBuildings = options.includeBuildings !== false;
  const structuresOnly = options.structuresOnly === true;
  const start = {
    x: number(attacker.position_x),
    y: number(attacker.position_y),
  };
  const terrainFraction = firstTerrainFraction(start, finish, map);
  const attackerKey = battleEntityKey(attacker);
  let bestTarget = null;
  let bestFraction = terrainFraction;
  for (const target of [...participants, ...worldEntities]) {
    if (
      battleEntityKey(target) === attackerKey
      || target.dead
      || target.activated === false
      || Number(target.team_no) === Number(attacker.team_no)
    ) {
      continue;
    }
    if (target.entity_type === "building") {
      if (!includeBuildings || (structuresOnly && !target.is_structure)) {
        continue;
      }
    }
    const fraction = combatantHitFraction(start, finish, target);
    // A building is also terrain. Equality means the projectile hit that
    // building, matching the client rule which only prefers terrain when its
    // fraction is strictly smaller than the entity hit fraction.
    if (Number.isFinite(fraction) && fraction <= bestFraction + 0.000001) {
      bestTarget = target;
      bestFraction = fraction;
    }
  }
  return { target: bestTarget, fraction: bestFraction, terrainFraction };
}

export function battleTargetsInRadius(
  attacker,
  participants,
  worldEntities,
  center,
  radius,
  options = {},
) {
  const includeBuildings = options.includeBuildings === true;
  const structuresOnly = options.structuresOnly === true;
  const attackerKey = battleEntityKey(attacker);
  return [...participants, ...worldEntities].filter((target) => {
    if (
      battleEntityKey(target) === attackerKey
      || target.dead
      || target.activated === false
      || Number(target.team_no) === Number(attacker.team_no)
    ) {
      return false;
    }
    if (target.entity_type === "building") {
      if (!includeBuildings || (structuresOnly && !target.is_structure)) {
        return false;
      }
    }
    return Math.hypot(
      number(target.position_x) - center.x,
      number(target.position_y) - center.y,
    ) <= radius;
  });
}

export function battleTargetsInLine(
  attacker,
  participants,
  worldEntities,
  finish,
  halfWidth,
  map,
) {
  const start = { x: number(attacker.position_x), y: number(attacker.position_y) };
  const terrainFraction = firstTerrainFraction(start, finish, map);
  const attackerKey = battleEntityKey(attacker);
  return [...participants, ...worldEntities].filter((target) => {
    if (
      battleEntityKey(target) === attackerKey
      || target.dead
      || target.activated === false
      || target.entity_type === "building"
      || Number(target.team_no) === Number(attacker.team_no)
    ) {
      return false;
    }
    const fraction = segmentCircleFraction(start, finish, {
      x: number(target.position_x),
      y: number(target.position_y),
    }, halfWidth + number(target.hit_radius, 36));
    return fraction < terrainFraction;
  });
}

export function activateFootpointSpawner(worldEntities, buildingId, nowMs) {
  const footpoint = worldEntities.find((entity) => (
    entity.entity_type === "footpoint"
    && Number(entity.spawner_building_id) === Number(buildingId)
  ));
  if (!footpoint || footpoint.activated) {
    return false;
  }
  footpoint.activated = true;
  footpoint.dead = false;
  footpoint.hit_points = Number(footpoint.maximum_hit_points);
  footpoint.position_x = number(footpoint.spawn_x);
  footpoint.position_y = number(footpoint.spawn_y);
  footpoint.active_at = iso(nowMs + Number(footpoint.birth_ms));
  footpoint.respawn_at = null;
  return true;
}

function respawnWorldEntity(entity, nowMs) {
  entity.dead = false;
  entity.hit_points = Number(entity.maximum_hit_points);
  entity.position_x = number(entity.spawn_x);
  entity.position_y = number(entity.spawn_y);
  entity.move_direction = Number(entity.initial_direction) >= 0 ? 1 : -1;
  entity.respawn_at = null;
  entity.stun_until = null;
  entity.slow_until = null;
  entity.slow_factor = 0;
  entity.airstrike_marker_until = null;
  entity.burst_remaining = 0;
  entity.burst_ready_at = null;
  entity.attack_ready_at = null;
  if (entity.entity_type === "footpoint") {
    entity.active_at = iso(nowMs + Number(entity.birth_ms));
  }
}

function activeAt(value, nowMs) {
  return dateMs(value) > nowMs;
}

function nearestWorldAiTarget(source, participants, worldEntities, maximumRange) {
  let best = null;
  let bestDistance = Infinity;
  for (const target of [...participants, ...worldEntities]) {
    if (
      target.dead
      || target.activated === false
      || target.entity_type === "building"
      || battleEntityKey(target) === battleEntityKey(source)
      || Number(target.team_no) === Number(source.team_no)
    ) {
      continue;
    }
    const distance = Math.hypot(
      number(target.position_x) - number(source.position_x),
      number(target.position_y) - number(source.position_y),
    );
    if (distance <= maximumRange && distance < bestDistance) {
      best = target;
      bestDistance = distance;
    }
  }
  return best;
}

function launchWorldProjectile(source, target, projectiles) {
  const direction = normalizeVector(
    number(target.position_x) - number(source.position_x),
    number(target.position_y) - number(source.position_y),
  );
  const muzzleOffset = number(source.muzzle_offset);
  projectiles.push({
    source_entity_key: source.entity_key,
    source_team_no: Number(source.team_no),
    team_no: Number(source.team_no),
    projectile_type: source.entity_type === "chief"
      ? "chief"
      : String(rowTemplate(source)?.kind ?? "cannon"),
    position_x: number(source.position_x) + direction.x * muzzleOffset,
    position_y: number(source.position_y) + direction.y * muzzleOffset,
    direction_x: direction.x,
    direction_y: direction.y,
    speed: number(source.projectile_speed),
    remaining_distance: number(source.attack_range),
    damage: number(source.basic_attack_damage),
    penetration: number(source.penetration),
    damage_type: source.damage_type === "energy" ? "energy" : "physical",
    critical_chance_basis_points: 0,
    critical_damage_basis_points: 10_000,
  });
  source.attack_serial = Number(source.attack_serial) + 1;
  source.last_target_key = battleEntityKey(target);
}

function deterministicFraction(entity, salt) {
  let value = (
    Number(entity.spawner_building_id) * 2654435761
    + Number(entity.wander_sequence) * 2246822519
    + salt * 3266489917
  ) >>> 0;
  value ^= value >>> 16;
  value = Math.imul(value, 2246822519) >>> 0;
  value ^= value >>> 13;
  return (value >>> 0) / 0x1_0000_0000;
}

function footpointDirection(entity, target, roam, nowMs) {
  if (target) {
    return normalizeVector(
      number(target.position_x) - number(entity.position_x),
      number(target.position_y) - number(entity.position_y),
      true,
    );
  }
  const reached = Math.hypot(
    number(entity.wander_target_x) - number(entity.position_x),
    number(entity.wander_target_y) - number(entity.position_y),
  ) <= 18;
  if (!entity.wander_target_x || !entity.wander_target_y || reached || dateMs(entity.wander_ready_at) <= nowMs) {
    entity.wander_sequence = Number(entity.wander_sequence) + 1;
    const left = roam.x + FOOTPOINT_ROAM_PADDING;
    const right = roam.x + roam.width - FOOTPOINT_ROAM_PADDING;
    const top = roam.y + FOOTPOINT_ROAM_PADDING;
    const bottom = roam.y + roam.height - FOOTPOINT_ROAM_PADDING;
    entity.wander_target_x = left + (right - left) * deterministicFraction(entity, 1);
    entity.wander_target_y = top + (bottom - top) * deterministicFraction(entity, 2);
    entity.wander_ready_at = iso(nowMs + FOOTPOINT_WANDER_RESELECT_MS);
  }
  return normalizeVector(
    number(entity.wander_target_x) - number(entity.position_x),
    number(entity.wander_target_y) - number(entity.position_y),
    true,
  );
}

function advanceWorldProjectiles(context, seconds, nowMs) {
  const survivors = [];
  const collisionMap = worldCollisionMap(context.map, context.worldEntities);
  for (const projectile of context.projectiles) {
    const travel = Math.min(
      number(projectile.remaining_distance),
      number(projectile.speed) * seconds,
    );
    const finish = {
      x: number(projectile.position_x) + number(projectile.direction_x) * travel,
      y: number(projectile.position_y) + number(projectile.direction_y) * travel,
    };
    const hit = firstBattleTargetOnSegment(
      projectile,
      context.participants,
      context.worldEntities,
      finish,
      collisionMap,
      { includeBuildings: false },
    );
    if (hit.target && hit.fraction <= hit.terrainFraction + 0.000001) {
      context.applyDamage(projectile, hit.target, number(projectile.damage), nowMs);
      context.emitEvent("world_projectile_hit", projectile, hit.target, {
        projectile_type: projectile.projectile_type,
      });
      continue;
    }
    if (Number.isFinite(hit.terrainFraction)) {
      context.emitEvent("world_projectile_terrain", projectile, null, {
        projectile_type: projectile.projectile_type,
      });
      continue;
    }
    projectile.position_x = finish.x;
    projectile.position_y = finish.y;
    projectile.remaining_distance = Math.max(
      0,
      number(projectile.remaining_distance) - travel,
    );
    if (projectile.remaining_distance > 0.001) {
      survivors.push(projectile);
    }
  }
  context.projectiles.splice(0, context.projectiles.length, ...survivors);
}

export function processBattleWorldStep(context, startMs, endMs) {
  const seconds = Math.max(0, endMs - startMs) / 1000;
  if (seconds <= 0) {
    return false;
  }
  let changed = false;
  let collisionMap = worldCollisionMap(context.map, context.worldEntities);
  for (const entity of context.worldEntities) {
    if (!entity.activated) {
      continue;
    }
    if (entity.dead) {
      if (entity.entity_type !== "building" && dateMs(entity.respawn_at) > 0 && dateMs(entity.respawn_at) <= endMs) {
        respawnWorldEntity(entity, endMs);
        context.emitEvent("world_respawn", entity, entity);
        changed = true;
      }
      continue;
    }
    if (activeAt(entity.active_at, endMs)) {
      continue;
    }
    if (entity.entity_type === "building") {
      if (!entity.can_attack || activeAt(entity.stun_until, endMs)) {
        continue;
      }
      if (dateMs(entity.attack_ready_at) > endMs) {
        continue;
      }
      const target = nearestWorldAiTarget(
        entity,
        context.participants,
        context.worldEntities,
        number(entity.attack_range),
      );
      if (target) {
        launchWorldProjectile(entity, target, context.projectiles);
        entity.attack_ready_at = iso(endMs + Number(entity.attack_interval_ms));
        context.emitEvent("world_attack", entity, target, {
          attack_serial: Number(entity.attack_serial),
        });
        changed = true;
      }
      continue;
    }
    if (entity.entity_type === "chief") {
      if (activeAt(entity.stun_until, endMs)) {
        continue;
      }
      const target = nearestWorldAiTarget(
        entity,
        context.participants,
        context.worldEntities,
        number(entity.attack_range),
      );
      if (
        Number(entity.burst_remaining) <= 0
        && dateMs(entity.attack_ready_at) <= endMs
        && target
      ) {
        entity.burst_remaining = Number(entity.burst_shots);
        entity.burst_ready_at = iso(endMs);
      }
      if (Number(entity.burst_remaining) > 0 && target) {
        if (dateMs(entity.burst_ready_at) <= endMs) {
          launchWorldProjectile(entity, target, context.projectiles);
          entity.burst_remaining = Number(entity.burst_remaining) - 1;
          if (entity.burst_remaining > 0) {
            entity.burst_ready_at = iso(endMs + Number(entity.burst_break_ms));
          } else {
            entity.attack_ready_at = iso(endMs + Number(entity.attack_interval_ms));
            entity.burst_ready_at = null;
          }
          context.emitEvent("world_attack", entity, target, {
            attack_serial: Number(entity.attack_serial),
          });
          changed = true;
        }
        continue;
      }
      const direction = Number(entity.move_direction) >= 0 ? 1 : -1;
      let nextX = number(entity.position_x) + direction * number(entity.move_speed) * seconds;
      if (nextX >= number(entity.patrol_right_x)) {
        nextX = number(entity.patrol_right_x);
        entity.move_direction = -1;
      } else if (nextX <= number(entity.patrol_left_x)) {
        nextX = number(entity.patrol_left_x);
        entity.move_direction = 1;
      }
      const slowMultiplier = activeAt(entity.slow_until, endMs)
        ? 1 - Math.max(0, Math.min(1, number(entity.slow_factor)))
        : 1;
      const desiredMotion = {
        x: (nextX - number(entity.position_x)) * slowMultiplier,
        y: 0,
      };
      const moved = moveTankWithCollision(
        { x: number(entity.position_x), y: number(entity.position_y) },
        desiredMotion,
        collisionMap,
      );
      if (Math.abs(moved.x - number(entity.position_x)) > 0.001) {
        entity.position_x = moved.x;
        entity.position_y = moved.y;
        changed = true;
      } else if (Math.abs(desiredMotion.x) > 0.001) {
        entity.move_direction = -direction;
      }
      continue;
    }
    if (entity.entity_type === "footpoint") {
      if (activeAt(entity.stun_until, endMs)) {
        continue;
      }
      const target = nearestWorldAiTarget(
        entity,
        context.participants,
        [],
        number(entity.attack_range),
      );
      const direction = footpointDirection(
        entity,
        target,
        context.map.footpointRoamRectangle,
        endMs,
      );
      const slowMultiplier = activeAt(entity.slow_until, endMs)
        ? 1 - Math.max(0, Math.min(1, number(entity.slow_factor)))
        : 1;
      const anchor = moveTankWithCollision(
        { x: number(entity.position_x), y: number(entity.position_y) - 12 },
        {
          x: direction.x * number(entity.move_speed) * slowMultiplier * seconds,
          y: direction.y * number(entity.move_speed) * slowMultiplier * seconds,
        },
        collisionMap,
      );
      const roam = context.map.footpointRoamRectangle;
      entity.position_x = Math.max(roam.x, Math.min(roam.x + roam.width, anchor.x));
      entity.position_y = Math.max(roam.y, Math.min(roam.y + roam.height, anchor.y + 12));
      const touched = context.participants.some((participant) => (
        !participant.dead
        && Math.hypot(
          number(participant.position_x) - number(entity.position_x),
          number(participant.position_y) - number(entity.position_y),
        ) <= number(entity.contact_radius)
      ));
      if (touched) {
        for (const participant of context.participants) {
          if (
            !participant.dead
            && Math.hypot(
              number(participant.position_x) - number(entity.position_x),
              number(participant.position_y) - number(entity.position_y),
            ) <= number(entity.explosion_radius)
          ) {
            context.applyDamage(
              entity,
              participant,
              number(entity.explosion_damage),
              endMs,
            );
          }
        }
        entity.hit_points = 0;
        entity.dead = true;
        entity.respawn_at = iso(endMs + Number(entity.respawn_ms));
        context.emitEvent("footpoint_explode", entity, null);
      }
      changed = true;
    }
  }
  advanceWorldProjectiles(context, seconds, endMs);
  return changed;
}

export function battleWorldSnapshot(entities, nowMs) {
  return entities.map((entity) => ({
    entity_key: entity.entity_key,
    entity_type: entity.entity_type,
    template_id: entity.template_id == null ? null : Number(entity.template_id),
    spawner_building_id: entity.spawner_building_id == null
      ? null
      : Number(entity.spawner_building_id),
    team_no: Number(entity.team_no),
    position_x: number(entity.position_x),
    position_y: number(entity.position_y),
    hit_points: Number(entity.hit_points),
    maximum_hit_points: Number(entity.maximum_hit_points),
    dead: entity.dead === true,
    activated: entity.activated === true,
    active_remaining_ms: Math.max(0, dateMs(entity.active_at) - nowMs),
    respawn_remaining_ms: Math.max(0, dateMs(entity.respawn_at) - nowMs),
    is_structure: entity.is_structure === true,
    attack_serial: Number(entity.attack_serial),
    last_target_key: entity.last_target_key,
    move_direction: Number(entity.move_direction),
  }));
}
