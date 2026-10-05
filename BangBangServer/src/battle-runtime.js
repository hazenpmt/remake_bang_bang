import { randomInt, randomUUID } from "node:crypto";

import { withReadTransaction, withTransaction } from "./db.js";
import { getBattleKit } from "./battle-kit-catalog.js";
import { loadBattleMap } from "./battle-map-catalog.js";
import { settleBattleRewards } from "./battle-rewards.js";
import {
  BATTLE_ASSIST_WINDOW_MS,
  BATTLE_INPUT_LEASE_MS,
  BATTLE_PROTOCOL_VERSION,
  BATTLE_RESPAWN_INVULNERABILITY_MS,
  BATTLE_RESPAWN_MS,
  BATTLE_SHIELD_RECHARGE_MS,
  calculateBattleDamage,
  enemiesInRadius,
  firstTerrainFraction,
  moveTankWithCollision,
  normalizeVector,
  validateBattleCommandRequest,
} from "./battle-policy.js";
import { loadBattleParticipantStats } from "./battle-stats.js";
import {
  activateFootpointSpawner,
  battleEntityKey,
  battleTargetsInLine,
  battleTargetsInRadius,
  battleWorldSnapshot,
  ensureBattleWorldInitialized,
  firstBattleTargetOnSegment,
  isWorldEntity,
  loadBattleWorldForUpdate,
  loadBattleWorldProjectilesForUpdate,
  persistBattleWorld,
  persistBattleWorldProjectiles,
  processBattleWorldStep,
  worldCollisionMap,
} from "./battle-world.js";

const MAX_EFFECT_TICKS_PER_ADVANCE = 64;
const BATTLE_WORLD_FIXED_STEP_MS = 50;
const MAX_WORLD_STEPS_PER_ADVANCE = 5000;
const MAX_MEMORY_COMMAND_REPLAYS_PER_ACCOUNT = 256;

export class BattleRuntimeError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function dateMs(value) {
  if (!value) {
    return 0;
  }
  const result = new Date(value).getTime();
  return Number.isFinite(result) ? result : 0;
}

function iso(ms) {
  return new Date(ms).toISOString();
}

function participantKey(value) {
  return `${Number(value.team_no)}:${Number(value.slot_no)}`;
}

function isParticipantCombatant(value) {
  return (
    !isWorldEntity(value)
    && !value?.source_entity_key
    && [1, 2].includes(Number(value?.team_no))
    && Number.isInteger(Number(value?.slot_no))
    && Number(value.slot_no) >= 1
    && Number(value.slot_no) <= 5
  );
}

function number(value, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function battleContextError(code, message, status = 409) {
  throw new BattleRuntimeError(status, code, message);
}

async function currentBattleContext(client, accountId) {
  const result = await client.query(
    `SELECT match.*,
            participant.team_no AS viewer_team_no,
            participant.slot_no AS viewer_slot_no,
            participant.account_id AS viewer_account_id
       FROM game_match_participants participant
       JOIN game_matches match ON match.id = participant.match_id
      WHERE participant.account_id = $1
        AND NOT participant.is_bot
        AND match.phase <> 'cancelled'
      ORDER BY match.created_at DESC, match.id DESC
      LIMIT 1
      FOR UPDATE OF match, participant`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    battleContextError("BATTLE_NOT_FOUND", "Không có trận đấu đang hoạt động.", 404);
  }
  const match = result.rows[0];
  if (match.is_test) {
    battleContextError(
      "BATTLE_SANDBOX_LOCAL",
      "Sandbox TEST dùng mô phỏng local tách biệt, không ghi kết quả online.",
    );
  }
  if (!["active", "finished"].includes(match.phase)) {
    battleContextError(
      "BATTLE_NOT_ACTIVE",
      "Trận đấu chưa chuyển sang trạng thái chiến đấu.",
    );
  }
  return match;
}

async function currentBattleContextReadOnly(client, accountId) {
  const result = await client.query(
    `SELECT match.*,
            participant.team_no AS viewer_team_no,
            participant.slot_no AS viewer_slot_no,
            participant.account_id AS viewer_account_id
       FROM game_match_participants participant
       JOIN game_matches match ON match.id = participant.match_id
      WHERE participant.account_id = $1
        AND NOT participant.is_bot
        AND match.phase <> 'cancelled'
      ORDER BY match.created_at DESC, match.id DESC
      LIMIT 1`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    battleContextError("BATTLE_NOT_FOUND", "Không có trận đấu đang hoạt động.", 404);
  }
  const match = result.rows[0];
  if (match.is_test) {
    battleContextError(
      "BATTLE_SANDBOX_LOCAL",
      "Sandbox TEST dùng mô phỏng local tách biệt, không ghi kết quả online.",
    );
  }
  if (!["active", "finished"].includes(match.phase)) {
    battleContextError(
      "BATTLE_NOT_ACTIVE",
      "Trận đấu chưa chuyển sang trạng thái chiến đấu.",
    );
  }
  return match;
}

async function ensureBattleInitialized(client, match, map) {
  const existing = await client.query(
    "SELECT COUNT(*)::int AS count FROM game_match_battle_participants WHERE match_id = $1",
    [match.id],
  );
  if (existing.rows[0].count > 0) {
    const worldInitialized = await ensureBattleWorldInitialized(client, match, map);
    if (
      worldInitialized
      || Number(match.battle_protocol_version) !== BATTLE_PROTOCOL_VERSION
    ) {
      await client.query(
        `UPDATE game_matches
            SET battle_protocol_version = $2,
                battle_revision = battle_revision + CASE WHEN $3 THEN 1 ELSE 0 END,
                updated_at = NOW()
          WHERE id = $1`,
        [match.id, BATTLE_PROTOCOL_VERSION, worldInitialized],
      );
      match.battle_protocol_version = BATTLE_PROTOCOL_VERSION;
      if (worldInitialized) {
        match.battle_revision = Number(match.battle_revision) + 1;
      }
    }
    return worldInitialized;
  }
  const participantResult = await client.query(
    `SELECT team_no,
            slot_no,
            account_id,
            is_bot,
            tank_key,
            tank_level
       FROM game_match_participants
      WHERE match_id = $1
      ORDER BY team_no, slot_no
      FOR UPDATE`,
    [match.id],
  );
  if (participantResult.rowCount === 0) {
    battleContextError("BATTLE_PARTICIPANTS_MISSING", "Trận đấu không có người chơi.");
  }

  for (const participant of participantResult.rows) {
    const spawn = map.spawnBySlot.get(participantKey(participant));
    if (!spawn) {
      battleContextError("BATTLE_SPAWN_MISSING", "Bản đồ thiếu vị trí xuất phát.");
    }
    const stats = await loadBattleParticipantStats(client, participant);
    const battleKit = getBattleKit(stats.battleKitKey);
    const shield = battleKit
      ? Math.max(0, Math.round(stats.hitPoints * battleKit.passiveShieldRatio))
      : 0;
    const skillReadyAt = Object.fromEntries(
      stats.skillCooldownMs.map((_cooldown, index) => [String(index + 1), null]),
    );
    await client.query(
      `INSERT INTO game_match_battle_participants (
         match_id,
         team_no,
         slot_no,
         account_id,
         is_bot,
         tank_key,
         battle_kit_key,
         position_x,
         position_y,
         spawn_x,
         spawn_y,
         hit_points,
         maximum_hit_points,
         shield_points,
         maximum_shield_points,
         basic_attack_damage,
         penetration,
         physical_armor,
         energy_shield,
         move_speed,
         fire_rate,
         attack_range,
         critical_chance_basis_points,
         critical_damage_basis_points,
         damage_type,
         skill_cooldown_ms,
         skill_ready_at
       )
       VALUES (
         $1, $2, $3, $4, $5, $6, $7,
         $8, $9, $8, $9,
         $10, $10, $11, $11,
         $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22::jsonb, $23::jsonb
       )`,
      [
        match.id,
        participant.team_no,
        participant.slot_no,
        participant.account_id,
        participant.is_bot,
        stats.tankKey,
        stats.battleKitKey,
        spawn.x,
        spawn.y,
        stats.hitPoints,
        shield,
        stats.basicAttackDamage,
        stats.penetration,
        stats.physicalArmor,
        stats.energyShield,
        stats.moveSpeed,
        stats.fireRate,
        stats.attackRange,
        stats.criticalChanceBasisPoints,
        stats.criticalDamageBasisPoints,
        stats.damageType,
        JSON.stringify(Object.fromEntries(
          stats.skillCooldownMs.map((cooldown, index) => [String(index + 1), cooldown]),
        )),
        JSON.stringify(skillReadyAt),
      ],
    );
  }
  await client.query(
    `UPDATE game_matches
        SET battle_protocol_version = $2,
            battle_revision = 1,
            battle_simulated_at = COALESCE(activated_at, NOW()),
            updated_at = NOW()
      WHERE id = $1`,
    [match.id, BATTLE_PROTOCOL_VERSION],
  );
  match.battle_protocol_version = BATTLE_PROTOCOL_VERSION;
  match.battle_revision = 1;
  match.battle_simulated_at = match.activated_at ?? new Date();
  await ensureBattleWorldInitialized(client, match, map);
  return true;
}

async function loadParticipantsForUpdate(client, matchId) {
  const result = await client.query(
    `SELECT *
       FROM game_match_battle_participants
      WHERE match_id = $1
      ORDER BY team_no, slot_no
      FOR UPDATE`,
    [matchId],
  );
  return result.rows;
}

function skillReadyAt(participant, slot) {
  const value = participant.skill_ready_at?.[String(slot)];
  return dateMs(value);
}

function setSkillReadyAt(participant, slot, valueMs) {
  participant.skill_ready_at = {
    ...(participant.skill_ready_at ?? {}),
    [String(slot)]: iso(valueMs),
  };
}

function respawnParticipant(participant, nowMs) {
  participant.position_x = number(participant.spawn_x);
  participant.position_y = number(participant.spawn_y);
  participant.hit_points = Number(participant.maximum_hit_points);
  participant.shield_points = Number(participant.maximum_shield_points);
  participant.shield_recharge_at = null;
  participant.dead = false;
  participant.respawn_at = null;
  participant.invulnerable_until = iso(nowMs + BATTLE_RESPAWN_INVULNERABILITY_MS);
  participant.input_x = 0;
  participant.input_y = 0;
  participant.input_expires_at = null;
  participant.slow_until = null;
  participant.slow_factor = 0;
  participant.airstrike_marker_until = null;
  participant.stun_until = null;
}

function activeAt(value, nowMs) {
  return dateMs(value) > nowMs;
}

async function persistParticipants(client, participants) {
  if (participants.length === 0) {
    return;
  }
  const matchId = participants[0].match_id;
  if (participants.some((participant) => String(participant.match_id) !== String(matchId))) {
    throw new Error("Cannot persist battle participants from different matches in one batch.");
  }
  const state = participants.map((participant) => ({
    team_no: Number(participant.team_no),
    slot_no: Number(participant.slot_no),
    position_x: number(participant.position_x),
    position_y: number(participant.position_y),
    input_x: number(participant.input_x),
    input_y: number(participant.input_y),
    input_expires_at: participant.input_expires_at ?? null,
    hit_points: Number(participant.hit_points),
    shield_points: Number(participant.shield_points),
    shield_recharge_at: participant.shield_recharge_at ?? null,
    basic_attack_ready_at: participant.basic_attack_ready_at ?? null,
    skill_ready_at: participant.skill_ready_at ?? {},
    slow_until: participant.slow_until ?? null,
    slow_factor: number(participant.slow_factor),
    airstrike_marker_until: participant.airstrike_marker_until ?? null,
    stun_until: participant.stun_until ?? null,
    dead: participant.dead === true,
    respawn_at: participant.respawn_at ?? null,
    invulnerable_until: participant.invulnerable_until ?? null,
    free_respawns_remaining: Number(participant.free_respawns_remaining),
    kills: Number(participant.kills),
    deaths: Number(participant.deaths),
    assists: Number(participant.assists),
    damage_contributors: participant.damage_contributors ?? {},
    last_sequence: Number(participant.last_sequence),
    last_command_at: participant.last_command_at ?? null,
  }));
  const result = await client.query(
    `WITH state AS (
       SELECT *
         FROM jsonb_to_recordset($2::jsonb) AS value(
           team_no smallint, slot_no smallint,
           position_x numeric, position_y numeric,
           input_x numeric, input_y numeric, input_expires_at timestamptz,
           hit_points integer, shield_points integer,
           shield_recharge_at timestamptz, basic_attack_ready_at timestamptz,
           skill_ready_at jsonb, slow_until timestamptz, slow_factor numeric,
           airstrike_marker_until timestamptz, stun_until timestamptz,
           dead boolean, respawn_at timestamptz, invulnerable_until timestamptz,
           free_respawns_remaining smallint,
           kills integer, deaths integer, assists integer,
           damage_contributors jsonb, last_sequence bigint,
           last_command_at timestamptz
         )
     )
     UPDATE game_match_battle_participants AS participant
        SET position_x = state.position_x,
            position_y = state.position_y,
            input_x = state.input_x,
            input_y = state.input_y,
            input_expires_at = state.input_expires_at,
            hit_points = state.hit_points,
            shield_points = state.shield_points,
            shield_recharge_at = state.shield_recharge_at,
            basic_attack_ready_at = state.basic_attack_ready_at,
            skill_ready_at = state.skill_ready_at,
            slow_until = state.slow_until,
            slow_factor = state.slow_factor,
            airstrike_marker_until = state.airstrike_marker_until,
            stun_until = state.stun_until,
            dead = state.dead,
            respawn_at = state.respawn_at,
            invulnerable_until = state.invulnerable_until,
            free_respawns_remaining = state.free_respawns_remaining,
            kills = state.kills,
            deaths = state.deaths,
            assists = state.assists,
            damage_contributors = state.damage_contributors,
            last_sequence = state.last_sequence,
            last_command_at = state.last_command_at,
            updated_at = NOW()
       FROM state
      WHERE participant.match_id = $1
        AND participant.team_no = state.team_no
        AND participant.slot_no = state.slot_no`,
    [matchId, JSON.stringify(state)],
  );
  if (result.rowCount !== participants.length) {
    throw new Error(
      `Persisted ${result.rowCount} of ${participants.length} battle participants for match ${matchId}.`,
    );
  }
}

function addEvent(events, type, actor, target = null, payload = {}) {
  const actorParticipant = isParticipantCombatant(actor);
  const targetParticipant = isParticipantCombatant(target);
  events.push({
    type,
    actorTeam: actorParticipant ? Number(actor.team_no) : null,
    actorSlot: actorParticipant ? Number(actor.slot_no) : null,
    targetTeam: targetParticipant ? Number(target.team_no) : null,
    targetSlot: targetParticipant ? Number(target.slot_no) : null,
    payload: {
      ...payload,
      ...(actor ? { actor_entity_key: battleEntityKey(actor) } : {}),
      ...(target ? { target_entity_key: battleEntityKey(target) } : {}),
    },
  });
}

async function persistBattleEvents(client, matchId, revision, events) {
  if (events.length === 0) {
    return;
  }
  const rows = events.map((event) => ({
    event_type: event.type,
    actor_team_no: event.actorTeam,
    actor_slot_no: event.actorSlot,
    target_team_no: event.targetTeam,
    target_slot_no: event.targetSlot,
    payload: event.payload ?? {},
  }));
  const result = await client.query(
    `INSERT INTO game_match_battle_events (
       match_id, revision, event_type,
       actor_team_no, actor_slot_no,
       target_team_no, target_slot_no,
       payload
     )
     SELECT $1, $2, event_type,
            actor_team_no, actor_slot_no,
            target_team_no, target_slot_no,
            payload
       FROM jsonb_to_recordset($3::jsonb) AS event(
         event_type varchar(32),
         actor_team_no smallint, actor_slot_no smallint,
         target_team_no smallint, target_slot_no smallint,
         payload jsonb
       )`,
    [matchId, revision, JSON.stringify(rows)],
  );
  if (result.rowCount !== events.length) {
    throw new Error(
      `Persisted ${result.rowCount} of ${events.length} battle events for match ${matchId}.`,
    );
  }
}

async function persistBattleEventBatch(client, matchId, events) {
  if (events.length === 0) {
    return;
  }
  const rows = events.map((event) => ({
    event_key: event.eventKey ??= randomUUID(),
    revision: Number(event.revision),
    event_type: event.type,
    actor_team_no: event.actorTeam,
    actor_slot_no: event.actorSlot,
    target_team_no: event.targetTeam,
    target_slot_no: event.targetSlot,
    payload: event.payload ?? {},
  }));
  const result = await client.query(
    `INSERT INTO game_match_battle_events (
       match_id, event_key, revision, event_type,
       actor_team_no, actor_slot_no,
       target_team_no, target_slot_no,
       payload
     )
     SELECT $1, event_key, revision, event_type,
            actor_team_no, actor_slot_no,
            target_team_no, target_slot_no,
            payload
       FROM jsonb_to_recordset($2::jsonb) AS event(
         event_key uuid, revision bigint, event_type varchar(32),
         actor_team_no smallint, actor_slot_no smallint,
         target_team_no smallint, target_slot_no smallint,
         payload jsonb
       )
     ON CONFLICT (event_key) WHERE event_key IS NOT NULL DO NOTHING`,
    [matchId, JSON.stringify(rows)],
  );
}

async function persistBattleEffects(client, matchId, effects) {
  await client.query(
    "DELETE FROM game_match_battle_effects WHERE match_id = $1",
    [matchId],
  );
  if (effects.length === 0) {
    return;
  }
  const rows = effects.map((effect) => ({
    owner_team_no: Number(effect.owner_team_no),
    owner_slot_no: Number(effect.owner_slot_no),
    effect_type: effect.effect_type,
    origin_x: number(effect.origin_x),
    origin_y: number(effect.origin_y),
    direction_x: number(effect.direction_x, 1),
    direction_y: number(effect.direction_y),
    radius: number(effect.radius),
    range_value: number(effect.range_value),
    half_width: number(effect.half_width),
    damage_ratio: number(effect.damage_ratio),
    next_tick_at: effect.next_tick_at,
    tick_interval_ms: Number(effect.tick_interval_ms),
    ends_at: effect.ends_at,
    created_at: effect.created_at ?? new Date().toISOString(),
    updated_at: effect.updated_at ?? new Date().toISOString(),
  }));
  const result = await client.query(
    `INSERT INTO game_match_battle_effects (
       match_id, owner_team_no, owner_slot_no, effect_type,
       origin_x, origin_y, direction_x, direction_y,
       radius, range_value, half_width, damage_ratio,
       next_tick_at, tick_interval_ms, ends_at, created_at, updated_at
     )
     SELECT $1, owner_team_no, owner_slot_no, effect_type,
            origin_x, origin_y, direction_x, direction_y,
            radius, range_value, half_width, damage_ratio,
            next_tick_at, tick_interval_ms, ends_at, created_at, updated_at
       FROM jsonb_to_recordset($2::jsonb) AS effect(
         owner_team_no smallint, owner_slot_no smallint,
         effect_type varchar(24),
         origin_x numeric, origin_y numeric,
         direction_x numeric, direction_y numeric,
         radius numeric, range_value numeric, half_width numeric,
         damage_ratio numeric, next_tick_at timestamptz,
         tick_interval_ms integer, ends_at timestamptz,
         created_at timestamptz, updated_at timestamptz
       )`,
    [matchId, JSON.stringify(rows)],
  );
  if (result.rowCount !== effects.length) {
    throw new Error(
      `Persisted ${result.rowCount} of ${effects.length} battle effects for match ${matchId}.`,
    );
  }
}

async function persistBattleCommandBatch(client, matchId, commands) {
  if (commands.length === 0) {
    return;
  }
  const rows = commands.map((command) => ({
    account_id: String(command.accountId),
    sequence_no: Number(command.sequence),
    command_type: command.command.type,
    payload: command.command,
    payload_hash: command.payloadHash,
    response_payload: command.response,
    created_at: command.appliedAt,
  }));
  const conflicts = await client.query(
    `WITH queued AS (
       SELECT *
         FROM jsonb_to_recordset($2::jsonb) AS command(
           account_id bigint, sequence_no bigint, payload_hash char(64)
         )
     )
     SELECT stored.account_id, stored.sequence_no, stored.payload_hash
       FROM game_match_battle_commands stored
       JOIN queued
         ON queued.account_id = stored.account_id
        AND queued.sequence_no = stored.sequence_no
      WHERE stored.match_id = $1`,
    [matchId, JSON.stringify(rows)],
  );
  for (const conflict of conflicts.rows) {
    const queued = rows.find((command) => (
      String(command.account_id) === String(conflict.account_id)
      && Number(command.sequence_no) === Number(conflict.sequence_no)
    ));
    if (!queued || queued.payload_hash !== String(conflict.payload_hash).trim()) {
      throw new Error(
        `Battle command journal conflict for match ${matchId}, account ${conflict.account_id}, sequence ${conflict.sequence_no}.`,
      );
    }
  }
  await client.query(
    `INSERT INTO game_match_battle_commands (
       match_id, account_id, sequence_no, command_type,
       payload, payload_hash, response_payload, created_at
     )
     SELECT $1, account_id, sequence_no, command_type,
            payload, payload_hash, response_payload, created_at
       FROM jsonb_to_recordset($2::jsonb) AS command(
         account_id bigint, sequence_no bigint, command_type varchar(24),
         payload jsonb, payload_hash char(64), response_payload jsonb,
         created_at timestamptz
       )
     ON CONFLICT (match_id, account_id, sequence_no) DO NOTHING`,
    [matchId, JSON.stringify(rows)],
  );
}

function awardDeath(match, attacker, target, participants, nowMs, events) {
  target.deaths = Number(target.deaths) + 1;
  target.dead = true;
  target.respawn_at = iso(nowMs + BATTLE_RESPAWN_MS);
  target.invulnerable_until = null;
  target.input_x = 0;
  target.input_y = 0;
  target.input_expires_at = null;
  if (
    attacker
    && [1, 2].includes(Number(attacker.team_no))
    && Number(attacker.team_no) !== Number(target.team_no)
  ) {
    if (isParticipantCombatant(attacker)) {
      attacker.kills = Number(attacker.kills) + 1;
    }
    const scoreField = Number(attacker.team_no) === 1
      ? "team_1_score"
      : "team_2_score";
    match[scoreField] = Number(match[scoreField]) + 1;
    const contributorRows = target.damage_contributors ?? {};
    for (const participant of participants) {
      if (
        participant === attacker
        || Number(participant.team_no) !== Number(attacker.team_no)
      ) {
        continue;
      }
      const contributedAt = Number(contributorRows[participantKey(participant)] ?? 0);
      if (contributedAt > 0 && nowMs - contributedAt <= BATTLE_ASSIST_WINDOW_MS) {
        participant.assists = Number(participant.assists) + 1;
      }
    }
  }
  target.damage_contributors = {};
  addEvent(events, "death", attacker, target, {
    team_1_score: Number(match.team_1_score),
    team_2_score: Number(match.team_2_score),
  });
}

function awardWorldDeath(
  match,
  attacker,
  target,
  participants,
  worldEntities,
  map,
  nowMs,
  events,
) {
  target.dead = true;
  target.hit_points = 0;
  target.stun_until = null;
  target.slow_until = null;
  target.slow_factor = 0;
  target.burst_remaining = 0;
  target.burst_ready_at = null;
  if (target.entity_type === "building") {
    target.respawn_at = null;
    if (
      Number(target.template_id) === 2006
      && [46, 47].includes(Number(String(target.entity_key).split(":")[1]))
    ) {
      activateFootpointSpawner(
        worldEntities,
        Number(String(target.entity_key).split(":")[1]),
        nowMs,
      );
    }
  } else {
    target.respawn_at = iso(nowMs + Number(target.respawn_ms));
  }
  if (
    target.entity_type === "chief"
    && attacker
    && [1, 2].includes(Number(attacker.team_no))
    && Number(attacker.team_no) !== Number(target.team_no)
  ) {
    const scoreField = Number(attacker.team_no) === 1
      ? "team_1_score"
      : "team_2_score";
    match[scoreField] = Number(match[scoreField]) + Number(map.chiefKillPoints);
  }
  addEvent(events, "world_death", attacker, target, {
    entity_type: target.entity_type,
    team_1_score: Number(match.team_1_score),
    team_2_score: Number(match.team_2_score),
  });
}

function applyDamage(
  match,
  attacker,
  target,
  rawDamage,
  participants,
  nowMs,
  events,
  worldEntities = [],
  map = null,
) {
  if (
    !target
    || target.dead
    || activeAt(target.invulnerable_until, nowMs)
    || rawDamage <= 0
  ) {
    return 0;
  }
  const damageResult = calculateBattleDamage(
    attacker,
    target,
    rawDamage,
    randomInt(0, 10_000),
  );
  if (isWorldEntity(target)) {
    const previousHealth = Number(target.hit_points);
    let actualDamage = 0;
    if (target.entity_type === "building" && Number(target.hits_to_destroy) > 0) {
      target.hit_count = Math.min(
        Number(target.hits_to_destroy),
        Number(target.hit_count) + 1,
      );
      const remainingHits = Math.max(
        0,
        Number(target.hits_to_destroy) - Number(target.hit_count),
      );
      target.hit_points = Math.round(
        Number(target.maximum_hit_points)
        * remainingHits
        / Number(target.hits_to_destroy),
      );
      actualDamage = Math.max(1, previousHealth - Number(target.hit_points));
    } else {
      actualDamage = Math.min(previousHealth, damageResult.damage);
      target.hit_points = previousHealth - actualDamage;
    }
    if (actualDamage <= 0) {
      return 0;
    }
    addEvent(events, "damage", attacker, target, {
      damage: actualDamage,
      critical: damageResult.critical,
      hit_points: Number(target.hit_points),
      shield_points: 0,
    });
    if (Number(target.hit_points) <= 0) {
      awardWorldDeath(
        match,
        attacker,
        target,
        participants,
        worldEntities,
        map,
        nowMs,
        events,
      );
    }
    return actualDamage;
  }
  let remainingDamage = Math.min(
    damageResult.damage,
    Number(target.hit_points) + Number(target.shield_points),
  );
  const previousShield = Number(target.shield_points);
  const absorbed = Math.min(Number(target.shield_points), remainingDamage);
  target.shield_points = Number(target.shield_points) - absorbed;
  remainingDamage -= absorbed;
  if (absorbed > 0 && Number(target.shield_points) <= 0) {
    target.shield_recharge_at = iso(nowMs + BATTLE_SHIELD_RECHARGE_MS);
  }
  const healthDamage = Math.min(Number(target.hit_points), remainingDamage);
  target.hit_points = Number(target.hit_points) - healthDamage;
  const actualDamage = absorbed + healthDamage;
  if (actualDamage <= 0) {
    return 0;
  }
  if (isParticipantCombatant(attacker)) {
    target.damage_contributors = {
      ...(target.damage_contributors ?? {}),
      [participantKey(attacker)]: nowMs,
    };
  }
  addEvent(events, "damage", attacker, target, {
    damage: actualDamage,
    critical: damageResult.critical,
    hit_points: Number(target.hit_points),
    shield_points: Number(target.shield_points),
  });
  const targetKit = getBattleKit(target.battle_kit_key);
  if (
    targetKit
    && previousShield > 0
    && Number(target.shield_points) <= 0
    && targetKit.shieldBreakDamageRatio > 0
  ) {
    addEvent(events, "shield_break", target, target);
    const retaliationTargets = map
      ? battleTargetsInRadius(
        target,
        participants,
        worldEntities,
        { x: number(target.position_x), y: number(target.position_y) },
        targetKit.shieldBreakRadius,
      )
      : enemiesInRadius(
        target,
        participants,
        { x: number(target.position_x), y: number(target.position_y) },
        targetKit.shieldBreakRadius,
      );
    for (const retaliationTarget of retaliationTargets) {
      applyDamage(
        match,
        target,
        retaliationTarget,
        number(target.basic_attack_damage) * targetKit.shieldBreakDamageRatio,
        participants,
        nowMs,
        events,
        worldEntities,
        map,
      );
    }
  }
  if (Number(target.hit_points) <= 0) {
    awardDeath(match, attacker, target, participants, nowMs, events);
  }
  return actualDamage;
}

function healParticipant(participant, amount) {
  if (participant.dead || amount <= 0) {
    return 0;
  }
  const previous = Number(participant.hit_points);
  participant.hit_points = Math.min(
    Number(participant.maximum_hit_points),
    previous + Math.round(amount),
  );
  return Number(participant.hit_points) - previous;
}

function finishBattleState(match, winnerTeamNo, reason, nowMs) {
  if (match.phase === "finished") {
    return false;
  }
  match.phase = "finished";
  match.winner_team_no = winnerTeamNo;
  match.finish_reason = reason;
  match.battle_ended_at = iso(nowMs);
  return true;
}

async function finishBattle(
  client,
  match,
  participants,
  winnerTeamNo,
  reason,
  nowMs,
) {
  if (!finishBattleState(match, winnerTeamNo, reason, nowMs)) {
    return false;
  }
  await client.query(
    `UPDATE game_matches
        SET phase = 'finished',
            winner_team_no = $2,
            finish_reason = $3,
            battle_ended_at = $4,
            team_1_score = $5,
            team_2_score = $6,
            updated_at = NOW()
      WHERE id = $1`,
    [
      match.id,
      winnerTeamNo,
      reason,
      match.battle_ended_at,
      Number(match.team_1_score),
      Number(match.team_2_score),
    ],
  );
  const roomIds = [match.team_a_room_id, match.team_b_room_id].filter(Boolean);
  await client.query(
    `UPDATE game_rooms
        SET status = 'waiting', updated_at = NOW()
      WHERE id = ANY($1::bigint[])`,
    [roomIds],
  );
  await client.query(
    "DELETE FROM game_room_matchmaking WHERE room_id = ANY($1::bigint[])",
    [roomIds],
  );
  await settleBattleRewards(
    client,
    match,
    participants,
    winnerTeamNo,
    new Date(nowMs),
  );
  return true;
}

async function processEffects(
  effectStore,
  match,
  participants,
  effects,
  map,
  nowMs,
  events,
  worldEntities = [],
) {
  let changed = false;
  let processedTicks = 0;
  for (const effect of effects) {
    const owner = participants.find((participant) => (
      Number(participant.team_no) === Number(effect.owner_team_no)
      && Number(participant.slot_no) === Number(effect.owner_slot_no)
    ));
    let nextTickMs = dateMs(effect.next_tick_at);
    const endsAtMs = dateMs(effect.ends_at);
    while (
      owner
      && !owner.dead
      && nextTickMs <= nowMs
      && nextTickMs <= endsAtMs
      && processedTicks < MAX_EFFECT_TICKS_PER_ADVANCE
    ) {
      let targets = [];
      if (effect.effect_type === "airstrike") {
        targets = battleTargetsInRadius(
          owner,
          participants,
          worldEntities,
          {
            x: number(effect.origin_x),
            y: number(effect.origin_y),
          },
          number(effect.radius),
          { includeBuildings: true, structuresOnly: true },
        );
        for (const target of targets) {
          applyDamage(
            match,
            owner,
            target,
            number(owner.basic_attack_damage)
              * number(effect.damage_ratio)
              * (target.is_structure ? 0.5 : 1),
            participants,
            nextTickMs,
            events,
            worldEntities,
            map,
          );
          target.slow_until = iso(nextTickMs + 1000);
          target.slow_factor = 0.5;
          target.airstrike_marker_until = iso(nextTickMs + 1000);
        }
      } else if (effect.effect_type === "beam") {
        const direction = normalizeVector(effect.direction_x, effect.direction_y);
        const finish = {
          x: number(owner.position_x) + direction.x * number(effect.range_value),
          y: number(owner.position_y) + direction.y * number(effect.range_value),
        };
        targets = battleTargetsInLine(
          owner,
          participants,
          worldEntities,
          finish,
          number(effect.half_width),
          map,
        );
        let dealt = 0;
        for (const target of targets) {
          dealt += applyDamage(
            match,
            owner,
            target,
            number(owner.basic_attack_damage) * number(effect.damage_ratio),
            participants,
            nextTickMs,
            events,
            worldEntities,
            map,
          );
        }
        const ownerKit = getBattleKit(owner.battle_kit_key);
        const healed = healParticipant(
          owner,
          dealt * number(ownerKit?.beamLifeStealRatio),
        );
        if (healed > 0) {
          addEvent(events, "heal", owner, owner, { healing: healed });
        }
      }
      processedTicks += 1;
      changed = true;
      nextTickMs += Number(effect.tick_interval_ms);
    }
    if (!owner || owner.dead || nextTickMs > endsAtMs) {
      await effectStore.remove(effect);
    } else {
      await effectStore.advance(
        effect,
        iso(nextTickMs),
        number(owner.position_x),
        number(owner.position_y),
        nowMs,
      );
    }
  }
  return changed;
}

async function advanceBattle(client, match, map, now = new Date()) {
  const nowMs = now.getTime();
  const previousSimulatedMs = dateMs(match.battle_simulated_at) || nowMs;
  const participants = await loadParticipantsForUpdate(client, match.id);
  const worldEntities = await loadBattleWorldForUpdate(client, match.id);
  const worldProjectiles = await loadBattleWorldProjectilesForUpdate(
    client,
    match.id,
  );
  const effectResult = await client.query(
    `SELECT *
       FROM game_match_battle_effects
      WHERE match_id = $1
      ORDER BY next_tick_at, id
      FOR UPDATE`,
    [match.id],
  );
  const effects = effectResult.rows;
  const beamOwners = new Set(
    effects.filter((effect) => effect.effect_type === "beam")
      .map((effect) => `${effect.owner_team_no}:${effect.owner_slot_no}`),
  );
  let changed = false;
  const events = [];

  if (match.phase === "active") {
    const movementMap = worldCollisionMap(map, worldEntities);
    for (const participant of participants) {
      if (participant.dead && dateMs(participant.respawn_at) <= nowMs) {
        respawnParticipant(participant, nowMs);
        addEvent(events, "respawn", participant, participant);
        changed = true;
      }
      if (
        !participant.dead
        && Number(participant.shield_points) <= 0
        && dateMs(participant.shield_recharge_at) > 0
        && dateMs(participant.shield_recharge_at) <= nowMs
      ) {
        participant.shield_points = Number(participant.maximum_shield_points);
        participant.shield_recharge_at = null;
        changed = true;
      }
      if (
        participant.dead
        || activeAt(participant.stun_until, nowMs)
        || beamOwners.has(participantKey(participant))
      ) {
        continue;
      }
      const movementEndMs = Math.min(nowMs, dateMs(participant.input_expires_at));
      if (movementEndMs <= previousSimulatedMs) {
        continue;
      }
      const directionX = number(participant.input_x);
      const directionY = number(participant.input_y);
      if (Math.hypot(directionX, directionY) <= 0.0001) {
        continue;
      }
      const slowMultiplier = activeAt(participant.slow_until, nowMs)
        ? 1 - Math.max(0, Math.min(1, number(participant.slow_factor)))
        : 1;
      const seconds = Math.min(
        movementEndMs - previousSimulatedMs,
        BATTLE_INPUT_LEASE_MS,
      ) / 1000;
      const position = moveTankWithCollision(
        { x: number(participant.position_x), y: number(participant.position_y) },
        {
          x: directionX * number(participant.move_speed) * slowMultiplier * seconds,
          y: directionY * number(participant.move_speed) * slowMultiplier * seconds,
        },
        movementMap,
      );
      if (
        Math.abs(position.x - number(participant.position_x)) > 0.001
        || Math.abs(position.y - number(participant.position_y)) > 0.001
      ) {
        participant.position_x = position.x;
        participant.position_y = position.y;
        changed = true;
      }
    }
    const worldContext = {
      match,
      participants,
      worldEntities,
      projectiles: worldProjectiles,
      map,
      applyDamage: (attacker, target, rawDamage, damageAtMs) => applyDamage(
        match,
        attacker,
        target,
        rawDamage,
        participants,
        damageAtMs,
        events,
        worldEntities,
        worldCollisionMap(map, worldEntities),
      ),
      emitEvent: (type, actor, target = null, payload = {}) => addEvent(
        events,
        type,
        actor,
        target,
        payload,
      ),
    };
    let stepStartMs = Math.max(
      previousSimulatedMs,
      nowMs - BATTLE_WORLD_FIXED_STEP_MS * MAX_WORLD_STEPS_PER_ADVANCE,
    );
    while (stepStartMs < nowMs) {
      const stepEndMs = Math.min(
        nowMs,
        stepStartMs + BATTLE_WORLD_FIXED_STEP_MS,
      );
      changed = processBattleWorldStep(
        worldContext,
        stepStartMs,
        stepEndMs,
      ) || changed;
      stepStartMs = stepEndMs;
    }
    const effectMap = worldCollisionMap(map, worldEntities);
    changed = await processEffects(
      databaseEffectStore(client, match),
      match,
      participants,
      effects,
      effectMap,
      nowMs,
      events,
      worldEntities,
    ) || changed;

    const elapsedMs = nowMs - dateMs(match.activated_at);
    if (Number(match.team_1_score) >= map.scoreLimit) {
      changed = await finishBattle(
        client, match, participants, 1, "score_limit", nowMs,
      ) || changed;
    } else if (Number(match.team_2_score) >= map.scoreLimit) {
      changed = await finishBattle(
        client, match, participants, 2, "score_limit", nowMs,
      ) || changed;
    } else if (elapsedMs >= map.durationSeconds * 1000) {
      const first = Number(match.team_1_score);
      const second = Number(match.team_2_score);
      const winner = first === second ? 0 : (first > second ? 1 : 2);
      changed = await finishBattle(
        client, match, participants, winner, "time_limit", nowMs,
      ) || changed;
    }
  }

  const revision = Number(match.battle_revision) + (changed ? 1 : 0);
  await persistParticipants(client, participants);
  await persistBattleWorld(client, worldEntities);
  await persistBattleWorldProjectiles(client, match.id, worldProjectiles);
  await client.query(
    `UPDATE game_matches
        SET battle_simulated_at = $2,
            battle_revision = $3,
            team_1_score = $4,
            team_2_score = $5,
            updated_at = CASE WHEN $6 THEN NOW() ELSE updated_at END
      WHERE id = $1`,
    [
      match.id,
      now,
      revision,
      Number(match.team_1_score),
      Number(match.team_2_score),
      changed,
    ],
  );
  match.battle_simulated_at = now;
  match.battle_revision = revision;
  await persistBattleEvents(client, match.id, revision, events);
  return { participants, worldEntities, effects, changed };
}

function remainingMs(value, nowMs) {
  return Math.max(0, dateMs(value) - nowMs);
}

async function snapshotPayload(client, match, accountId, now = new Date()) {
  const result = await client.query(
    `SELECT battle.*,
            participant.display_name,
            participant.gender,
            participant.avatar_key,
            participant.equipped_skin_key,
            reward.experience_reward AS reward_experience,
            reward.silver_reward AS reward_silver,
            reward.level_after AS reward_level_after,
            reward.experience_after AS reward_experience_after,
            reward.silver_after AS reward_silver_after
       FROM game_match_battle_participants battle
       JOIN game_match_participants participant
         ON participant.match_id = battle.match_id
         AND participant.team_no = battle.team_no
         AND participant.slot_no = battle.slot_no
       LEFT JOIN game_match_battle_rewards reward
         ON reward.match_id = battle.match_id
        AND reward.team_no = battle.team_no
        AND reward.slot_no = battle.slot_no
      WHERE battle.match_id = $1
      ORDER BY battle.team_no, battle.slot_no`,
    [match.id],
  );
  const nowMs = now.getTime();
  const worldResult = await client.query(
    `SELECT *
       FROM game_match_battle_world_entities
      WHERE match_id = $1
      ORDER BY entity_type, entity_key`,
    [match.id],
  );
  const worldEntities = worldResult.rows.map((row) => ({
    ...row,
    team_no: Number(row.team_no),
    position_x: number(row.position_x),
    position_y: number(row.position_y),
    hit_points: Number(row.hit_points),
    maximum_hit_points: Number(row.maximum_hit_points),
    attack_serial: Number(row.attack_serial),
    move_direction: Number(row.move_direction),
  }));
  const entities = result.rows.map((participant) => ({
    account_id: participant.account_id == null ? null : String(participant.account_id),
    team_no: Number(participant.team_no),
    slot_no: Number(participant.slot_no),
    is_bot: participant.is_bot,
    display_name: participant.display_name,
    gender: participant.gender,
    avatar_key: participant.avatar_key,
    tank_key: participant.tank_key,
    battle_kit_key: participant.battle_kit_key,
    equipped_skin_key: participant.equipped_skin_key,
    position_x: number(participant.position_x),
    position_y: number(participant.position_y),
    hit_points: Number(participant.hit_points),
    maximum_hit_points: Number(participant.maximum_hit_points),
    shield_points: Number(participant.shield_points),
    maximum_shield_points: Number(participant.maximum_shield_points),
    dead: participant.dead,
    respawn_remaining_ms: remainingMs(participant.respawn_at, nowMs),
    invulnerable_remaining_ms: remainingMs(participant.invulnerable_until, nowMs),
    basic_attack_cooldown_ms: remainingMs(participant.basic_attack_ready_at, nowMs),
    skill_cooldowns_ms: Object.fromEntries(
      [1, 2, 3].map((slot) => [
        String(slot),
        remainingMs(participant.skill_ready_at?.[String(slot)], nowMs),
      ]),
    ),
    kills: Number(participant.kills),
    deaths: Number(participant.deaths),
    assists: Number(participant.assists),
    free_respawns_remaining: Number(participant.free_respawns_remaining),
    last_processed_sequence: Number(participant.last_sequence),
    ...(participant.reward_experience == null ? {} : {
      experience_reward: Number(participant.reward_experience),
      silver_reward: Number(participant.reward_silver),
      level_after: Number(participant.reward_level_after),
      experience_after: Number(participant.reward_experience_after),
      silver_after: Number(participant.reward_silver_after),
    }),
  }));
  const viewer = entities.find(
    (participant) => String(participant.account_id) === String(accountId),
  );
  const durationMs = (await loadBattleMap(match.map_key)).durationSeconds * 1000;
  const elapsedMs = Math.max(0, Math.min(
    durationMs,
    (match.phase === "finished" ? dateMs(match.battle_ended_at) : nowMs)
      - dateMs(match.activated_at),
  ));
  const winner = match.winner_team_no == null ? null : Number(match.winner_team_no);
  return {
    protocol_version: Number(match.battle_protocol_version),
    state_epoch: Number(match.battle_worker_epoch ?? 0),
    match_id: String(match.id),
    phase: match.phase,
    revision: Number(match.battle_revision),
    server_time: now.toISOString(),
    elapsed_ms: elapsedMs,
    duration_ms: durationMs,
    team_1_score: Number(match.team_1_score),
    team_2_score: Number(match.team_2_score),
    viewer_team_no: viewer?.team_no ?? null,
    viewer_slot_no: viewer?.slot_no ?? null,
    last_processed_sequence: viewer?.last_processed_sequence ?? 0,
    entities,
    world_entities: battleWorldSnapshot(worldEntities, nowMs),
    result: match.phase === "finished"
      ? {
        winner_team_no: winner,
        finish_reason: match.finish_reason,
        viewer_outcome: winner === 0
          ? "draw"
          : (winner === viewer?.team_no ? "win" : "lose"),
        reward: viewer?.experience_reward == null
          ? null
          : {
            experience: viewer.experience_reward,
            silver: viewer.silver_reward,
            level_after: viewer.level_after,
            experience_after: viewer.experience_after,
            silver_after: viewer.silver_after,
          },
      }
      : null,
  };
}

async function insertEffect(client, match, participant, values) {
  await client.query(
    `INSERT INTO game_match_battle_effects (
       match_id, owner_team_no, owner_slot_no, effect_type,
       origin_x, origin_y, direction_x, direction_y,
       radius, range_value, half_width, damage_ratio,
       next_tick_at, tick_interval_ms, ends_at
     )
     VALUES (
       $1, $2, $3, $4,
       $5, $6, $7, $8,
       $9, $10, $11, $12,
       $13, $14, $15
     )`,
    [
      match.id,
      participant.team_no,
      participant.slot_no,
      values.type,
      values.origin.x,
      values.origin.y,
      values.direction?.x ?? 1,
      values.direction?.y ?? 0,
      values.radius ?? 0,
      values.range ?? 0,
      values.halfWidth ?? 0,
      values.damageRatio,
      values.nextTickAt,
      values.tickIntervalMs,
      values.endsAt,
    ],
  );
}

function databaseEffectStore(client, match) {
  return {
    async insert(participant, values) {
      await insertEffect(client, match, participant, values);
    },
    async findBeam(participant) {
      const result = await client.query(
        `SELECT *
           FROM game_match_battle_effects
          WHERE match_id = $1
            AND owner_team_no = $2
            AND owner_slot_no = $3
            AND effect_type = 'beam'
          FOR UPDATE`,
        [match.id, participant.team_no, participant.slot_no],
      );
      return result.rows[0] ?? null;
    },
    async updateBeamDirection(effect, directionX, directionY) {
      await client.query(
        `UPDATE game_match_battle_effects
            SET direction_x = $2,
                direction_y = $3,
                updated_at = NOW()
          WHERE id = $1`,
        [effect.id, directionX, directionY],
      );
    },
    async cancelBeam(participant) {
      const deleted = await client.query(
        `DELETE FROM game_match_battle_effects
          WHERE match_id = $1
            AND owner_team_no = $2
            AND owner_slot_no = $3
            AND effect_type = 'beam'
            AND created_at <= NOW() - INTERVAL '1 second'`,
        [match.id, participant.team_no, participant.slot_no],
      );
      return deleted.rowCount === 1;
    },
    async remove(effect) {
      await client.query(
        "DELETE FROM game_match_battle_effects WHERE id = $1",
        [effect.id],
      );
    },
    async advance(effect, nextTickAt, ownerX, ownerY) {
      await client.query(
        `UPDATE game_match_battle_effects
            SET next_tick_at = $2,
                origin_x = CASE WHEN effect_type = 'beam' THEN $3 ELSE origin_x END,
                origin_y = CASE WHEN effect_type = 'beam' THEN $4 ELSE origin_y END,
                updated_at = NOW()
          WHERE id = $1`,
        [effect.id, nextTickAt, ownerX, ownerY],
      );
    },
  };
}

function memoryEffectStore(effects, nowMs) {
  let nextId = effects.reduce(
    (minimum, effect) => Math.min(minimum, Number(effect.id) || 0),
    0,
  ) - 1;
  return {
    async insert(participant, values) {
      effects.push({
        id: nextId,
        match_id: participant.match_id,
        owner_team_no: Number(participant.team_no),
        owner_slot_no: Number(participant.slot_no),
        effect_type: values.type,
        origin_x: values.origin.x,
        origin_y: values.origin.y,
        direction_x: values.direction?.x ?? 1,
        direction_y: values.direction?.y ?? 0,
        radius: values.radius ?? 0,
        range_value: values.range ?? 0,
        half_width: values.halfWidth ?? 0,
        damage_ratio: values.damageRatio,
        next_tick_at: values.nextTickAt,
        tick_interval_ms: values.tickIntervalMs,
        ends_at: values.endsAt,
        created_at: iso(nowMs),
        updated_at: iso(nowMs),
      });
      nextId -= 1;
    },
    async findBeam(participant) {
      return effects.find((effect) => (
        effect.effect_type === "beam"
        && Number(effect.owner_team_no) === Number(participant.team_no)
        && Number(effect.owner_slot_no) === Number(participant.slot_no)
      )) ?? null;
    },
    async updateBeamDirection(effect, directionX, directionY) {
      effect.direction_x = directionX;
      effect.direction_y = directionY;
      effect.updated_at = iso(nowMs);
    },
    async cancelBeam(participant) {
      const index = effects.findIndex((effect) => (
        effect.effect_type === "beam"
        && Number(effect.owner_team_no) === Number(participant.team_no)
        && Number(effect.owner_slot_no) === Number(participant.slot_no)
        && dateMs(effect.created_at) <= nowMs - 1_000
      ));
      if (index < 0) {
        return false;
      }
      effects.splice(index, 1);
      return true;
    },
    async remove(effect) {
      const index = effects.indexOf(effect);
      if (index >= 0) {
        effects.splice(index, 1);
      }
    },
    async advance(effect, nextTickAt, ownerX, ownerY, advancedAtMs) {
      effect.next_tick_at = nextTickAt;
      if (effect.effect_type === "beam") {
        effect.origin_x = ownerX;
        effect.origin_y = ownerY;
      }
      effect.updated_at = iso(advancedAtMs);
    },
  };
}

function requireLivingParticipant(participant) {
  if (participant.dead) {
    battleContextError("BATTLE_PLAYER_DEAD", "Tank đang chờ hồi sinh.");
  }
}

function requireReady(readyAt, nowMs, code, message) {
  const wait = remainingMs(readyAt, nowMs);
  if (wait > 0) {
    const error = new BattleRuntimeError(409, code, message);
    error.retryAfterMs = wait;
    throw error;
  }
}

async function applyCommand(
  runtime,
  match,
  map,
  participants,
  worldEntities,
  participant,
  command,
  nowMs,
  events,
) {
  if (match.phase !== "active") {
    battleContextError("BATTLE_FINISHED", "Trận đấu đã kết thúc.");
  }
  if (command.type === "move") {
    participant.input_x = command.x;
    participant.input_y = command.y;
    participant.input_expires_at = iso(nowMs + BATTLE_INPUT_LEASE_MS);
    return;
  }
  if (command.type === "respawn") {
    if (!participant.dead) {
      battleContextError("BATTLE_NOT_DEAD", "Tank chưa bị hạ.");
    }
    if (Number(participant.free_respawns_remaining) <= 0) {
      battleContextError("BATTLE_FREE_RESPAWN_USED", "Đã dùng lượt hồi sinh miễn phí.");
    }
    participant.free_respawns_remaining = Number(participant.free_respawns_remaining) - 1;
    respawnParticipant(participant, nowMs);
    addEvent(events, "respawn", participant, participant, { instant: true });
    return;
  }
  if (command.type === "surrender") {
    await runtime.finish(
      match,
      participants,
      Number(participant.team_no) === 1 ? 2 : 1,
      "surrender",
      nowMs,
    );
    addEvent(events, "surrender", participant);
    return;
  }
  requireLivingParticipant(participant);
  if (activeAt(participant.stun_until, nowMs)) {
    battleContextError("BATTLE_PLAYER_STUNNED", "Tank đang bị choáng.");
  }
  const origin = {
    x: number(participant.position_x),
    y: number(participant.position_y),
  };

  if (command.type === "basic_attack") {
    requireReady(
      participant.basic_attack_ready_at,
      nowMs,
      "BATTLE_ATTACK_COOLDOWN",
      "Đòn đánh thường chưa hồi xong.",
    );
    const direction = normalizeVector(
      command.target_x - origin.x,
      command.target_y - origin.y,
    );
    const finish = {
      x: origin.x + direction.x * number(participant.attack_range),
      y: origin.y + direction.y * number(participant.attack_range),
    };
    const combatMap = worldCollisionMap(map, worldEntities);
    const hit = firstBattleTargetOnSegment(
      participant,
      participants,
      worldEntities,
      finish,
      combatMap,
      { includeBuildings: true },
    );
    participant.basic_attack_ready_at = iso(
      nowMs + Math.ceil(60_000 / Math.max(1, number(participant.fire_rate))),
    );
    if (hit.target) {
      applyDamage(
        match,
        participant,
        hit.target,
        number(participant.basic_attack_damage),
        participants,
        nowMs,
        events,
        worldEntities,
        combatMap,
      );
    }
    addEvent(events, "basic_attack", participant, hit.target, {
      target_x: command.target_x,
      target_y: command.target_y,
    });
    return;
  }

  if (command.type === "skill") {
    const battleKit = getBattleKit(participant.battle_kit_key);
    if (!battleKit) {
      battleContextError(
        "BATTLE_SKILL_KIT_UNAVAILABLE",
        "Tank nĂ y chÆ°a cĂ³ bá»™ ká»¹ nÄƒng server.",
      );
    }
    const slot = command.slot;
    requireReady(
      participant.skill_ready_at?.[String(slot)],
      nowMs,
      "BATTLE_SKILL_COOLDOWN",
      "Kỹ năng chưa hồi xong.",
    );
    const target = { x: command.target_x, y: command.target_y };
    const direction = normalizeVector(target.x - origin.x, target.y - origin.y);
    const distance = Math.hypot(target.x - origin.x, target.y - origin.y);
    const cooldown = Math.max(
      500,
      Number(participant.skill_cooldown_ms?.[String(slot)])
        || [6000, 8000, 20000][slot - 1],
    );
    if (slot === 1) {
      const finish = {
        x: origin.x + direction.x * battleKit.skillRange,
        y: origin.y + direction.y * battleKit.skillRange,
      };
      const combatMap = worldCollisionMap(map, worldEntities);
      const hit = firstBattleTargetOnSegment(
        participant,
        participants,
        worldEntities,
        finish,
        combatMap,
        { includeBuildings: false },
      );
      const impactFraction = Math.min(
        hit.fraction,
        firstTerrainFraction(origin, finish, combatMap),
      );
      const impact = Number.isFinite(impactFraction)
        ? {
          x: origin.x + (finish.x - origin.x) * impactFraction,
          y: origin.y + (finish.y - origin.y) * impactFraction,
        }
        : finish;
      const targets = battleTargetsInRadius(
        participant,
        participants,
        worldEntities,
        impact,
        battleKit.skillOneRadius,
      );
      for (const enemy of targets) {
        if (activeAt(enemy.airstrike_marker_until, nowMs)) {
          enemy.stun_until = iso(nowMs + 1000);
        }
        applyDamage(
          match,
          participant,
          enemy,
          number(participant.basic_attack_damage) * battleKit.skillOneDamageRatio,
          participants,
          nowMs,
          events,
          worldEntities,
          combatMap,
        );
        enemy.slow_until = iso(nowMs + 2500);
        enemy.slow_factor = 0.75;
      }
      setSkillReadyAt(participant, slot, nowMs + cooldown);
    } else if (slot === 2) {
      if (distance > battleKit.skillRange + 0.001) {
        battleContextError("BATTLE_SKILL_RANGE", "Điểm thi triển vượt quá tầm kỹ năng.");
      }
      await runtime.effectStore.insert(participant, {
        type: "airstrike",
        origin: target,
        radius: battleKit.skillTwoRadius,
        damageRatio: battleKit.skillTwoDamageRatio,
        nextTickAt: iso(nowMs + 500),
        tickIntervalMs: 500,
        endsAt: iso(nowMs + 3000),
      });
      setSkillReadyAt(participant, slot, nowMs + cooldown);
    } else {
      const activeBeam = await runtime.effectStore.findBeam(participant);
      if (activeBeam) {
        battleContextError("BATTLE_SKILL_CHANNEL_ACTIVE", "Tia Tan Rã đang hoạt động.");
      }
      if (Number(participant.shield_points) <= 0) {
        participant.shield_points = Number(participant.maximum_shield_points);
        participant.shield_recharge_at = null;
      }
      await runtime.effectStore.insert(participant, {
        type: "beam",
        origin,
        direction,
        range: battleKit.skillRange,
        halfWidth: battleKit.beamHalfWidth,
        damageRatio: battleKit.beamDamageRatio,
        nextTickAt: iso(nowMs + 200),
        tickIntervalMs: 200,
        endsAt: iso(nowMs + 4000),
      });
      setSkillReadyAt(participant, slot, nowMs + 4000 + cooldown);
      participant.input_x = 0;
      participant.input_y = 0;
      participant.input_expires_at = null;
    }
    addEvent(events, "skill", participant, null, {
      slot,
      target_x: target.x,
      target_y: target.y,
    });
    return;
  }

  if (command.type === "skill_aim") {
    if (!getBattleKit(participant.battle_kit_key)) {
      battleContextError(
        "BATTLE_SKILL_KIT_UNAVAILABLE",
        "Tank nĂ y chÆ°a cĂ³ bá»™ ká»¹ nÄƒng server.",
      );
    }
    const effect = await runtime.effectStore.findBeam(participant);
    if (!effect) {
      battleContextError("BATTLE_SKILL_CHANNEL_MISSING", "Không có tia đang hoạt động.");
    }
    const desired = normalizeVector(
      command.target_x - origin.x,
      command.target_y - origin.y,
    );
    const currentAngle = Math.atan2(number(effect.direction_y), number(effect.direction_x));
    const desiredAngle = Math.atan2(desired.y, desired.x);
    let delta = ((desiredAngle - currentAngle + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    const elapsed = Math.max(0.01, (nowMs - dateMs(effect.updated_at)) / 1000);
    const maximumTurn = 20 * Math.PI / 180 * elapsed;
    delta = Math.max(-maximumTurn, Math.min(maximumTurn, delta));
    const angle = currentAngle + delta;
    await runtime.effectStore.updateBeamDirection(
      effect,
      Math.cos(angle),
      Math.sin(angle),
    );
    return;
  }

  if (command.type === "skill_cancel") {
    if (!getBattleKit(participant.battle_kit_key)) {
      battleContextError(
        "BATTLE_SKILL_KIT_UNAVAILABLE",
        "Tank nĂ y chÆ°a cĂ³ bá»™ ká»¹ nÄƒng server.",
      );
    }
    const cancelled = await runtime.effectStore.cancelBeam(participant);
    if (!cancelled) {
      battleContextError(
        "BATTLE_SKILL_CANCEL_EARLY",
        "Tia chỉ có thể hủy sau khi dẫn ít nhất 1 giây.",
      );
    }
  }
}

export async function advanceBattleMemoryState(state, now = new Date()) {
  const { match, map, participants, worldEntities, worldProjectiles, effects } = state;
  const requestedNowMs = now.getTime();
  const previousSimulatedMs = dateMs(match.battle_simulated_at) || requestedNowMs;
  const nowMs = Math.max(requestedNowMs, previousSimulatedMs);
  const beamOwners = new Set(
    effects.filter((effect) => effect.effect_type === "beam")
      .map((effect) => `${effect.owner_team_no}:${effect.owner_slot_no}`),
  );
  let changed = false;
  const events = [];

  if (match.phase === "active") {
    const movementMap = worldCollisionMap(map, worldEntities);
    for (const participant of participants) {
      if (participant.dead && dateMs(participant.respawn_at) <= nowMs) {
        respawnParticipant(participant, nowMs);
        addEvent(events, "respawn", participant, participant);
        changed = true;
      }
      if (
        !participant.dead
        && Number(participant.shield_points) <= 0
        && dateMs(participant.shield_recharge_at) > 0
        && dateMs(participant.shield_recharge_at) <= nowMs
      ) {
        participant.shield_points = Number(participant.maximum_shield_points);
        participant.shield_recharge_at = null;
        changed = true;
      }
      if (
        participant.dead
        || activeAt(participant.stun_until, nowMs)
        || beamOwners.has(participantKey(participant))
      ) {
        continue;
      }
      const movementEndMs = Math.min(nowMs, dateMs(participant.input_expires_at));
      if (movementEndMs <= previousSimulatedMs) {
        continue;
      }
      const directionX = number(participant.input_x);
      const directionY = number(participant.input_y);
      if (Math.hypot(directionX, directionY) <= 0.0001) {
        continue;
      }
      const slowMultiplier = activeAt(participant.slow_until, nowMs)
        ? 1 - Math.max(0, Math.min(1, number(participant.slow_factor)))
        : 1;
      const seconds = Math.min(
        movementEndMs - previousSimulatedMs,
        BATTLE_INPUT_LEASE_MS,
      ) / 1000;
      const position = moveTankWithCollision(
        { x: number(participant.position_x), y: number(participant.position_y) },
        {
          x: directionX * number(participant.move_speed) * slowMultiplier * seconds,
          y: directionY * number(participant.move_speed) * slowMultiplier * seconds,
        },
        movementMap,
      );
      if (
        Math.abs(position.x - number(participant.position_x)) > 0.001
        || Math.abs(position.y - number(participant.position_y)) > 0.001
      ) {
        participant.position_x = position.x;
        participant.position_y = position.y;
        changed = true;
      }
    }

    const worldContext = {
      match,
      participants,
      worldEntities,
      projectiles: worldProjectiles,
      map,
      applyDamage: (attacker, target, rawDamage, damageAtMs) => applyDamage(
        match,
        attacker,
        target,
        rawDamage,
        participants,
        damageAtMs,
        events,
        worldEntities,
        worldCollisionMap(map, worldEntities),
      ),
      emitEvent: (type, actor, target = null, payload = {}) => addEvent(
        events,
        type,
        actor,
        target,
        payload,
      ),
    };
    let stepStartMs = Math.max(
      previousSimulatedMs,
      nowMs - BATTLE_WORLD_FIXED_STEP_MS * MAX_WORLD_STEPS_PER_ADVANCE,
    );
    while (stepStartMs < nowMs) {
      const stepEndMs = Math.min(
        nowMs,
        stepStartMs + BATTLE_WORLD_FIXED_STEP_MS,
      );
      changed = processBattleWorldStep(
        worldContext,
        stepStartMs,
        stepEndMs,
      ) || changed;
      stepStartMs = stepEndMs;
    }

    changed = await processEffects(
      memoryEffectStore(effects, nowMs),
      match,
      participants,
      effects,
      worldCollisionMap(map, worldEntities),
      nowMs,
      events,
      worldEntities,
    ) || changed;

    const elapsedMs = nowMs - dateMs(match.activated_at);
    if (Number(match.team_1_score) >= map.scoreLimit) {
      changed = finishBattleState(match, 1, "score_limit", nowMs) || changed;
    } else if (Number(match.team_2_score) >= map.scoreLimit) {
      changed = finishBattleState(match, 2, "score_limit", nowMs) || changed;
    } else if (elapsedMs >= map.durationSeconds * 1000) {
      const first = Number(match.team_1_score);
      const second = Number(match.team_2_score);
      const winner = first === second ? 0 : (first > second ? 1 : 2);
      changed = finishBattleState(match, winner, "time_limit", nowMs) || changed;
    }
  }

  const revision = Number(match.battle_revision) + (changed ? 1 : 0);
  match.battle_simulated_at = iso(nowMs);
  match.battle_revision = revision;
  if (events.length > 0) {
    state.pendingEvents.push(
      ...events.map((event) => ({ ...event, revision })),
    );
  }
  state.dirty = state.dirty || changed;
  return { changed, events };
}

export function buildBattleMemorySnapshot(state, accountId, now = new Date()) {
  const { match, map, participants, worldEntities } = state;
  const nowMs = now.getTime();
  const entities = participants.map((participant) => ({
    account_id: participant.account_id == null ? null : String(participant.account_id),
    team_no: Number(participant.team_no),
    slot_no: Number(participant.slot_no),
    is_bot: participant.is_bot,
    display_name: participant.display_name,
    gender: participant.gender,
    avatar_key: participant.avatar_key,
    tank_key: participant.tank_key,
    battle_kit_key: participant.battle_kit_key,
    equipped_skin_key: participant.equipped_skin_key,
    position_x: number(participant.position_x),
    position_y: number(participant.position_y),
    hit_points: Number(participant.hit_points),
    maximum_hit_points: Number(participant.maximum_hit_points),
    shield_points: Number(participant.shield_points),
    maximum_shield_points: Number(participant.maximum_shield_points),
    dead: participant.dead,
    respawn_remaining_ms: remainingMs(participant.respawn_at, nowMs),
    invulnerable_remaining_ms: remainingMs(participant.invulnerable_until, nowMs),
    basic_attack_cooldown_ms: remainingMs(participant.basic_attack_ready_at, nowMs),
    skill_cooldowns_ms: Object.fromEntries(
      [1, 2, 3].map((slot) => [
        String(slot),
        remainingMs(participant.skill_ready_at?.[String(slot)], nowMs),
      ]),
    ),
    kills: Number(participant.kills),
    deaths: Number(participant.deaths),
    assists: Number(participant.assists),
    free_respawns_remaining: Number(participant.free_respawns_remaining),
    last_processed_sequence: Number(participant.last_sequence),
    ...(participant.reward_experience == null ? {} : {
      experience_reward: Number(participant.reward_experience),
      silver_reward: Number(participant.reward_silver),
      level_after: Number(participant.reward_level_after),
      experience_after: Number(participant.reward_experience_after),
      silver_after: Number(participant.reward_silver_after),
    }),
  }));
  const viewer = entities.find(
    (participant) => String(participant.account_id) === String(accountId),
  );
  const durationMs = map.durationSeconds * 1000;
  const elapsedMs = Math.max(0, Math.min(
    durationMs,
    (match.phase === "finished" ? dateMs(match.battle_ended_at) : nowMs)
      - dateMs(match.activated_at),
  ));
  const winner = match.winner_team_no == null ? null : Number(match.winner_team_no);
  return {
    protocol_version: Number(match.battle_protocol_version),
    state_epoch: Number(match.battle_worker_epoch ?? 0),
    match_id: String(match.id),
    phase: match.phase,
    revision: Number(match.battle_revision),
    server_time: now.toISOString(),
    elapsed_ms: elapsedMs,
    duration_ms: durationMs,
    team_1_score: Number(match.team_1_score),
    team_2_score: Number(match.team_2_score),
    viewer_team_no: viewer?.team_no ?? null,
    viewer_slot_no: viewer?.slot_no ?? null,
    last_processed_sequence: viewer?.last_processed_sequence ?? 0,
    entities,
    world_entities: battleWorldSnapshot(worldEntities, nowMs),
    result: match.phase === "finished"
      ? {
        winner_team_no: winner,
        finish_reason: match.finish_reason,
        viewer_outcome: winner === 0
          ? "draw"
          : (winner === viewer?.team_no ? "win" : "lose"),
        reward: viewer?.experience_reward == null
          ? null
          : {
            experience: viewer.experience_reward,
            silver: viewer.silver_reward,
            level_after: viewer.level_after,
            experience_after: viewer.experience_after,
            silver_after: viewer.silver_after,
          },
      }
      : null,
  };
}

export async function applyBattleMemoryCommand(
  state,
  accountId,
  body,
  now = new Date(),
) {
  let request;
  try {
    request = validateBattleCommandRequest(body);
  } catch (error) {
    throw new BattleRuntimeError(400, "INVALID_BATTLE_COMMAND", error.message);
  }
  const cacheKey = `${accountId}:${request.sequence}`;
  const replay = state.responseCache.get(cacheKey);
  if (replay) {
    if (replay.payloadHash !== request.payloadHash) {
      battleContextError(
        "BATTLE_SEQUENCE_CONFLICT",
        "Sequence cũ không được dùng lại với nội dung khác.",
      );
    }
    return { ...structuredClone(replay.response), replayed: true };
  }
  const participant = state.participants.find(
    (value) => String(value.account_id) === String(accountId),
  );
  if (!participant) {
    battleContextError("BATTLE_VIEWER_MISSING", "Không tìm thấy Tank của người chơi.");
  }
  const expected = Number(participant.last_sequence) + 1;
  if (request.sequence !== expected) {
    const error = new BattleRuntimeError(
      409,
      "BATTLE_SEQUENCE_GAP",
      `Sequence kế tiếp phải là ${expected}.`,
    );
    error.expectedSequence = expected;
    throw error;
  }

  const nowMs = now.getTime();
  const events = [];
  await applyCommand(
    {
      effectStore: memoryEffectStore(state.effects, nowMs),
      finish: async (match, _participants, winnerTeamNo, reason, finishAtMs) => (
        finishBattleState(match, winnerTeamNo, reason, finishAtMs)
      ),
    },
    state.match,
    state.map,
    state.participants,
    state.worldEntities,
    participant,
    request.command,
    nowMs,
    events,
  );
  if (
    state.match.phase === "active"
    && Number(state.match.team_1_score) >= state.map.scoreLimit
  ) {
    finishBattleState(state.match, 1, "score_limit", nowMs);
  } else if (
    state.match.phase === "active"
    && Number(state.match.team_2_score) >= state.map.scoreLimit
  ) {
    finishBattleState(state.match, 2, "score_limit", nowMs);
  }
  participant.last_sequence = request.sequence;
  participant.last_command_at = now.toISOString();
  state.match.battle_revision = Number(state.match.battle_revision) + 1;
  const revision = Number(state.match.battle_revision);
  state.pendingEvents.push(
    ...events.map((event) => ({ ...event, revision })),
  );
  state.dirty = true;
  const snapshot = buildBattleMemorySnapshot(state, accountId, now);
  const response = {
    accepted_sequence: request.sequence,
    snapshot,
    replayed: false,
  };
  state.responseCache.set(cacheKey, {
    payloadHash: request.payloadHash,
    response: structuredClone(response),
  });
  state.pendingCommands.push({
    accountId,
    sequence: request.sequence,
    command: structuredClone(request.command),
    payloadHash: request.payloadHash,
    response: structuredClone(response),
    appliedAt: now.toISOString(),
  });
  return response;
}

async function loadBattleMemoryParticipants(client, matchId) {
  const result = await client.query(
    `SELECT battle.*,
            participant.display_name,
            participant.gender,
            participant.avatar_key,
            participant.equipped_skin_key,
            reward.experience_reward AS reward_experience,
            reward.silver_reward AS reward_silver,
            reward.level_after AS reward_level_after,
            reward.experience_after AS reward_experience_after,
            reward.silver_after AS reward_silver_after
       FROM game_match_battle_participants battle
       JOIN game_match_participants participant
         ON participant.match_id = battle.match_id
        AND participant.team_no = battle.team_no
        AND participant.slot_no = battle.slot_no
       LEFT JOIN game_match_battle_rewards reward
         ON reward.match_id = battle.match_id
        AND reward.team_no = battle.team_no
        AND reward.slot_no = battle.slot_no
      WHERE battle.match_id = $1
      ORDER BY battle.team_no, battle.slot_no
      FOR UPDATE OF battle`,
    [matchId],
  );
  return result.rows;
}

async function hydrateBattleMemoryState(client, match, workerId, leaseMs, now) {
  const nowMs = now.getTime();
  if (match.phase === "active") {
    const claimed = await client.query(
      `UPDATE game_matches
          SET battle_worker_id = $2,
              battle_worker_epoch = battle_worker_epoch + 1,
              battle_worker_lease_until = $3,
              updated_at = NOW()
        WHERE id = $1
          AND (
            battle_worker_lease_until IS NULL
            OR battle_worker_lease_until <= NOW()
            OR battle_worker_id = $2
          )
        RETURNING *`,
      [match.id, workerId, new Date(nowMs + leaseMs)],
    );
    if (claimed.rowCount !== 1) {
      const error = new BattleRuntimeError(
        409,
        "BATTLE_WORKER_BUSY",
        "Trận đấu đang được một máy chủ trận đấu khác xử lý.",
      );
      error.retryAfterMs = leaseMs;
      throw error;
    }
    Object.assign(match, claimed.rows[0]);
  }

  const map = await loadBattleMap(match.map_key);
  await ensureBattleInitialized(client, match, map);
  await advanceBattle(client, match, map, now);
  if (match.phase === "finished") {
    const released = await client.query(
      `UPDATE game_matches
          SET battle_worker_id = NULL,
              battle_worker_lease_until = NULL,
              battle_checkpoint_at = COALESCE(battle_checkpoint_at, NOW()),
              updated_at = NOW()
        WHERE id = $1
        RETURNING *`,
      [match.id],
    );
    Object.assign(match, released.rows[0]);
  }

  const participants = await loadBattleMemoryParticipants(client, match.id);
  const worldEntities = await loadBattleWorldForUpdate(client, match.id);
  const worldProjectiles = await loadBattleWorldProjectilesForUpdate(client, match.id);
  const effectsResult = await client.query(
    `SELECT *
       FROM game_match_battle_effects
      WHERE match_id = $1
      ORDER BY id
      FOR UPDATE`,
    [match.id],
  );
  const commandsResult = await client.query(
    `SELECT account_id, sequence_no, payload_hash, response_payload
       FROM (
         SELECT account_id,
                sequence_no,
                payload_hash,
                response_payload,
                ROW_NUMBER() OVER (
                  PARTITION BY account_id ORDER BY id DESC
                ) AS replay_rank
           FROM game_match_battle_commands
          WHERE match_id = $1
       ) recent
      WHERE replay_rank <= $2
      ORDER BY account_id, sequence_no`,
    [match.id, MAX_MEMORY_COMMAND_REPLAYS_PER_ACCOUNT],
  );
  const responseCache = new Map();
  for (const command of commandsResult.rows.reverse()) {
    responseCache.set(`${command.account_id}:${command.sequence_no}`, {
      payloadHash: String(command.payload_hash).trim(),
      response: command.response_payload,
    });
  }
  return {
    match,
    map,
    participants,
    worldEntities,
    worldProjectiles,
    effects: effectsResult.rows,
    pendingEvents: [],
    pendingCommands: [],
    responseCache,
    workerId,
    workerEpoch: match.battle_worker_epoch,
    leaseMs,
    dirty: false,
    released: match.phase !== "active",
    lastCheckpointAt: nowMs,
  };
}

export async function hydrateBattleMemoryStateByAccount(
  accountId,
  workerId,
  leaseMs,
  now = new Date(),
) {
  return withTransaction(async (client) => {
    const match = await currentBattleContext(client, accountId);
    return hydrateBattleMemoryState(client, match, workerId, leaseMs, now);
  });
}

export async function hydrateBattleMemoryStateByMatchId(
  matchId,
  workerId,
  leaseMs,
  now = new Date(),
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT *
         FROM game_matches
        WHERE id = $1
          AND phase IN ('active', 'finished')
          AND NOT is_test
        FOR UPDATE`,
      [matchId],
    );
    if (result.rowCount !== 1) {
      battleContextError(
        "BATTLE_NOT_FOUND",
        "Không tìm thấy trận đấu đang hoạt động.",
        404,
      );
    }
    return hydrateBattleMemoryState(
      client,
      result.rows[0],
      workerId,
      leaseMs,
      now,
    );
  });
}

function applyBattleRewardRows(participants, rewards) {
  const bySlot = new Map(
    rewards.map((reward) => [`${reward.team_no}:${reward.slot_no}`, reward]),
  );
  for (const participant of participants) {
    const reward = bySlot.get(participantKey(participant));
    if (!reward) {
      continue;
    }
    participant.reward_experience = Number(reward.experience_reward);
    participant.reward_silver = Number(reward.silver_reward);
    participant.reward_level_after = Number(reward.level_after);
    participant.reward_experience_after = Number(reward.experience_after);
    participant.reward_silver_after = Number(reward.silver_after);
  }
}

function refreshUnacknowledgedFinalCommandResponses(state, now) {
  for (const command of state.pendingCommands) {
    if (
      command.response?.snapshot?.phase !== "finished"
      || command.response.snapshot.result?.reward != null
    ) {
      continue;
    }
    command.response = {
      accepted_sequence: command.sequence,
      snapshot: buildBattleMemorySnapshot(state, command.accountId, now),
      replayed: false,
    };
    state.responseCache.set(`${command.accountId}:${command.sequence}`, {
      payloadHash: command.payloadHash,
      response: structuredClone(command.response),
    });
  }
}

function pruneBattleResponseCache(state) {
  const entriesByAccount = new Map();
  for (const key of state.responseCache.keys()) {
    const separator = key.lastIndexOf(":");
    const accountId = key.slice(0, separator);
    const sequence = Number(key.slice(separator + 1));
    const entries = entriesByAccount.get(accountId) ?? [];
    entries.push({ key, sequence });
    entriesByAccount.set(accountId, entries);
  }
  for (const entries of entriesByAccount.values()) {
    entries.sort((first, second) => second.sequence - first.sequence);
    for (const entry of entries.slice(MAX_MEMORY_COMMAND_REPLAYS_PER_ACCOUNT)) {
      state.responseCache.delete(entry.key);
    }
  }
}

export async function checkpointBattleMemoryState(
  state,
  options = {},
) {
  if (state.released) {
    return false;
  }
  const now = options.now ?? new Date();
  const release = options.release === true;
  const eventCount = state.pendingEvents.length;
  const commandCount = state.pendingCommands.length;
  const pendingEvents = state.pendingEvents.slice(0, eventCount);
  const pendingCommands = state.pendingCommands.slice(0, commandCount);

  await withTransaction(async (client) => {
    const lockedResult = await client.query(
      "SELECT * FROM game_matches WHERE id = $1 FOR UPDATE",
      [state.match.id],
    );
    if (lockedResult.rowCount !== 1) {
      battleContextError("BATTLE_NOT_FOUND", "Trận đấu không còn tồn tại.", 404);
    }
    const locked = lockedResult.rows[0];
    if (
      String(locked.battle_worker_id ?? "") !== String(state.workerId)
      || String(locked.battle_worker_epoch) !== String(state.workerEpoch)
    ) {
      battleContextError(
        "BATTLE_WORKER_LEASE_LOST",
        "Quyền xử lý trận đấu đã được chuyển sang máy chủ khác.",
      );
    }

    await persistParticipants(client, state.participants);
    await persistBattleWorld(client, state.worldEntities);
    await persistBattleWorldProjectiles(
      client,
      state.match.id,
      state.worldProjectiles,
    );
    await persistBattleEffects(client, state.match.id, state.effects);
    await persistBattleEventBatch(client, state.match.id, pendingEvents);

    const releaseLease = release || state.match.phase !== "active";
    const updated = await client.query(
      `UPDATE game_matches
          SET phase = $2,
              winner_team_no = $3,
              finish_reason = $4,
              battle_ended_at = $5,
              battle_simulated_at = $6,
              battle_revision = $7,
              team_1_score = $8,
              team_2_score = $9,
              battle_checkpoint_at = $10::timestamptz,
              battle_worker_id = CASE WHEN $11 THEN NULL ELSE battle_worker_id END,
              battle_worker_lease_until = CASE
                WHEN $11 THEN NULL
                ELSE $10::timestamptz
                  + ($12::bigint * INTERVAL '1 millisecond')
              END,
              updated_at = NOW()
        WHERE id = $1
          AND battle_worker_id = $13
          AND battle_worker_epoch = $14
        RETURNING *`,
      [
        state.match.id,
        state.match.phase,
        state.match.winner_team_no,
        state.match.finish_reason,
        state.match.battle_ended_at,
        state.match.battle_simulated_at,
        Number(state.match.battle_revision),
        Number(state.match.team_1_score),
        Number(state.match.team_2_score),
        now,
        releaseLease,
        state.leaseMs,
        state.workerId,
        state.workerEpoch,
      ],
    );
    if (updated.rowCount !== 1) {
      battleContextError(
        "BATTLE_WORKER_LEASE_LOST",
        "Không thể checkpoint vì quyền xử lý trận đấu đã thay đổi.",
      );
    }
    Object.assign(state.match, updated.rows[0]);

    if (state.match.phase === "finished") {
      const roomIds = [
        state.match.team_a_room_id,
        state.match.team_b_room_id,
      ].filter(Boolean);
      if (roomIds.length > 0) {
        await client.query(
          `UPDATE game_rooms
              SET status = 'waiting', updated_at = NOW()
            WHERE id = ANY($1::bigint[])`,
          [roomIds],
        );
        await client.query(
          "DELETE FROM game_room_matchmaking WHERE room_id = ANY($1::bigint[])",
          [roomIds],
        );
      }
      const rewards = await settleBattleRewards(
        client,
        state.match,
        state.participants,
        Number(state.match.winner_team_no) || 0,
        new Date(state.match.battle_ended_at ?? now),
      );
      applyBattleRewardRows(state.participants, rewards);
      refreshUnacknowledgedFinalCommandResponses(state, now);
    }
    await persistBattleCommandBatch(client, state.match.id, pendingCommands);
  });

  state.pendingEvents.splice(0, eventCount);
  state.pendingCommands.splice(0, commandCount);
  state.dirty = false;
  state.lastCheckpointAt = now.getTime();
  pruneBattleResponseCache(state);
  if (release || state.match.phase !== "active") {
    state.released = true;
  }
  return true;
}

export async function getBattleSnapshot(accountId) {
  return withTransaction(async (client) => {
    const match = await currentBattleContext(client, accountId);
    const map = await loadBattleMap(match.map_key);
    await ensureBattleInitialized(client, match, map);
    const advanced = await advanceBattle(client, match, map);
    if (match.phase === "finished" && !match.reward_settled_at) {
      await settleBattleRewards(
        client,
        match,
        advanced.participants,
        Number(match.winner_team_no) || 0,
        new Date(match.battle_ended_at ?? Date.now()),
      );
    }
    return snapshotPayload(client, match, accountId);
  });
}

// Realtime pushes only read the state produced by the fixed ticker. They must
// never advance the simulation once per connected viewer, otherwise a 10-player
// match would be simulated repeatedly and would create avoidable write locks.
export async function readBattleSnapshot(accountId) {
  return withReadTransaction(async (client) => {
    const match = await currentBattleContextReadOnly(client, accountId);
    return snapshotPayload(client, match, accountId);
  });
}

export async function advanceBattleMatch(matchId, now = new Date()) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT *
         FROM game_matches
        WHERE id = $1 AND phase = 'active'
        FOR UPDATE`,
      [matchId],
    );
    if (result.rowCount !== 1) {
      return false;
    }
    const match = result.rows[0];
    if (match.is_test) {
      return false;
    }
    const map = await loadBattleMap(match.map_key);
    await ensureBattleInitialized(client, match, map);
    await advanceBattle(client, match, map, now);
    return true;
  });
}

export async function submitBattleCommand(accountId, body) {
  let request;
  try {
    request = validateBattleCommandRequest(body);
  } catch (error) {
    throw new BattleRuntimeError(
      400,
      "INVALID_BATTLE_COMMAND",
      error.message,
    );
  }
  return withTransaction(async (client) => {
    const match = await currentBattleContext(client, accountId);
    const replay = await client.query(
      `SELECT payload_hash, response_payload
         FROM game_match_battle_commands
        WHERE match_id = $1
          AND account_id = $2
          AND sequence_no = $3`,
      [match.id, accountId, request.sequence],
    );
    if (replay.rowCount === 1) {
      if (replay.rows[0].payload_hash !== request.payloadHash) {
        battleContextError(
          "BATTLE_SEQUENCE_CONFLICT",
          "Sequence cũ không được dùng lại với nội dung khác.",
        );
      }
      return { ...replay.rows[0].response_payload, replayed: true };
    }

    const map = await loadBattleMap(match.map_key);
    await ensureBattleInitialized(client, match, map);
    const advanced = await advanceBattle(client, match, map);
    const participants = advanced.participants;
    const worldEntities = advanced.worldEntities;
    const participant = participants.find(
      (value) => String(value.account_id) === String(accountId),
    );
    if (!participant) {
      battleContextError("BATTLE_VIEWER_MISSING", "Không tìm thấy Tank của người chơi.");
    }
    const expected = Number(participant.last_sequence) + 1;
    if (request.sequence !== expected) {
      const error = new BattleRuntimeError(
        409,
        "BATTLE_SEQUENCE_GAP",
        `Sequence kế tiếp phải là ${expected}.`,
      );
      error.expectedSequence = expected;
      throw error;
    }

    const now = new Date();
    const events = [];
    await applyCommand(
      {
        effectStore: databaseEffectStore(client, match),
        finish: (
          finishMatch,
          finishParticipants,
          winnerTeamNo,
          reason,
          finishAtMs,
        ) => finishBattle(
          client,
          finishMatch,
          finishParticipants,
          winnerTeamNo,
          reason,
          finishAtMs,
        ),
      },
      match,
      map,
      participants,
      worldEntities,
      participant,
      request.command,
      now.getTime(),
      events,
    );
    if (match.phase === "active" && Number(match.team_1_score) >= map.scoreLimit) {
      await finishBattle(
        client, match, participants, 1, "score_limit", now.getTime(),
      );
    } else if (
      match.phase === "active"
      && Number(match.team_2_score) >= map.scoreLimit
    ) {
      await finishBattle(
        client, match, participants, 2, "score_limit", now.getTime(),
      );
    }
    participant.last_sequence = request.sequence;
    participant.last_command_at = now;
    await persistParticipants(client, participants);
    await persistBattleWorld(client, worldEntities);
    match.battle_revision = Number(match.battle_revision) + 1;
    await client.query(
      `UPDATE game_matches
          SET battle_revision = $2,
              team_1_score = $3,
              team_2_score = $4,
              updated_at = NOW()
        WHERE id = $1`,
      [
        match.id,
        match.battle_revision,
        Number(match.team_1_score),
        Number(match.team_2_score),
      ],
    );
    await persistBattleEvents(
      client,
      match.id,
      match.battle_revision,
      events,
    );
    const snapshot = await snapshotPayload(client, match, accountId, now);
    const response = {
      accepted_sequence: request.sequence,
      snapshot,
      replayed: false,
    };
    await client.query(
      `INSERT INTO game_match_battle_commands (
         match_id,
         account_id,
         sequence_no,
         command_type,
         payload,
         payload_hash,
         response_payload
       ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7::jsonb)`,
      [
        match.id,
        accountId,
        request.sequence,
        request.command.type,
        JSON.stringify(request.command),
        request.payloadHash,
        JSON.stringify(response),
      ],
    );
    return response;
  });
}
