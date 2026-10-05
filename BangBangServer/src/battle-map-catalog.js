import { readFile } from "node:fs/promises";

import { getBattleBuildingTemplate } from "./battle-world-catalog.js";

const MAP_FILES = Object.freeze({
  random: "maya_score.json",
  maya_score: "maya_score.json",
});

const cache = new Map();

function finiteNumber(value, field) {
  const result = Number(value);
  if (!Number.isFinite(result)) {
    throw new Error(`Battle map field ${field} must be finite.`);
  }
  return result;
}

function positiveNumber(value, field) {
  const result = finiteNumber(value, field);
  if (result <= 0) {
    throw new Error(`Battle map field ${field} must be positive.`);
  }
  return result;
}

function rectangle(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`Battle map field ${field} must be an object.`);
  }
  return Object.freeze({
    x: finiteNumber(value.x, `${field}.x`),
    y: finiteNumber(value.y, `${field}.y`),
    width: positiveNumber(value.width, `${field}.width`),
    height: positiveNumber(value.height, `${field}.height`),
  });
}

function rectangleCenterDistanceSquared(point, value) {
  const deltaX = point.x - (value.x + value.width / 2);
  const deltaY = point.y - (value.y + value.height / 2);
  return deltaX * deltaX + deltaY * deltaY;
}

function worldBuildings(raw, buildingRectangles) {
  const values = Array.isArray(raw.world_buildings) ? raw.world_buildings : [];
  const seenIds = new Set();
  const claimedRectangles = new Set();
  return Object.freeze(values.map((value, index) => {
    const uniqueId = Number(value?.unique_id);
    const templateId = Number(value?.template_id);
    const teamNo = Number(value?.team_no);
    const position = {
      x: finiteNumber(value?.x, `world_buildings[${index}].x`),
      y: finiteNumber(value?.y, `world_buildings[${index}].y`),
    };
    if (!Number.isInteger(uniqueId) || uniqueId <= 0 || seenIds.has(uniqueId)) {
      throw new Error(`Battle map world building ${index} has an invalid unique_id.`);
    }
    if (!getBattleBuildingTemplate(templateId)) {
      throw new Error(`Battle map building ${uniqueId} uses unsupported template ${templateId}.`);
    }
    if (![0, 1, 2].includes(teamNo)) {
      throw new Error(`Battle map building ${uniqueId} has an invalid team.`);
    }
    const matches = buildingRectangles
      .map((collision, collisionIndex) => ({ collision, collisionIndex }))
      .filter(({ collisionIndex }) => !claimedRectangles.has(collisionIndex))
      .map((entry) => ({
        ...entry,
        distanceSquared: rectangleCenterDistanceSquared(position, entry.collision),
      }))
      .sort((first, second) => first.distanceSquared - second.distanceSquared);
    if (
      matches.length === 0
      || matches[0].distanceSquared > 96 * 96
      || (
        matches.length > 1
        && Math.abs(matches[0].distanceSquared - matches[1].distanceSquared) < 0.001
      )
    ) {
      throw new Error(
        `Battle map building ${uniqueId} must own exactly one collision rectangle.`,
      );
    }
    seenIds.add(uniqueId);
    claimedRectangles.add(matches[0].collisionIndex);
    return Object.freeze({
      entityKey: `building:${uniqueId}`,
      uniqueId,
      templateId,
      teamNo,
      ...position,
      collisionRectangles: Object.freeze([matches[0].collision]),
    });
  }));
}

function worldChiefs(raw) {
  const values = Array.isArray(raw.world_chiefs) ? raw.world_chiefs : [];
  const teams = new Set();
  return Object.freeze(values.map((value, index) => {
    const teamNo = Number(value?.team_no);
    const initialDirection = Number(value?.initial_direction);
    if (![1, 2].includes(teamNo) || teams.has(teamNo)) {
      throw new Error(`Battle map chief ${index} has an invalid or duplicate team.`);
    }
    if (![-1, 1].includes(initialDirection)) {
      throw new Error(`Battle map chief ${index} has an invalid direction.`);
    }
    const left = finiteNumber(value?.patrol_left_x, `world_chiefs[${index}].left`);
    const right = finiteNumber(value?.patrol_right_x, `world_chiefs[${index}].right`);
    if (right <= left) {
      throw new Error(`Battle map chief ${index} has an invalid patrol range.`);
    }
    teams.add(teamNo);
    return Object.freeze({
      entityKey: String(value?.entity_key ?? `chief:${teamNo}`),
      teamNo,
      x: finiteNumber(value?.x, `world_chiefs[${index}].x`),
      y: finiteNumber(value?.y, `world_chiefs[${index}].y`),
      patrolLeftX: left,
      patrolRightX: right,
      initialDirection,
    });
  }));
}

function footpointSpawners(raw, buildings) {
  const buildingIds = new Set(buildings.map((value) => value.uniqueId));
  const values = Array.isArray(raw.footpoint_spawners)
    ? raw.footpoint_spawners
    : [];
  return Object.freeze(values.map((value, index) => {
    const buildingId = Number(value?.building_id);
    if (!Number.isInteger(buildingId) || !buildingIds.has(buildingId)) {
      throw new Error(`Footpoint spawner ${index} references an unknown building.`);
    }
    return Object.freeze({
      entityKey: String(value?.entity_key ?? `footpoint:${buildingId}`),
      buildingId,
      x: finiteNumber(value?.x, `footpoint_spawners[${index}].x`),
      y: finiteNumber(value?.y, `footpoint_spawners[${index}].y`),
    });
  }));
}

function validateMap(raw, requestedMapKey) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error(`Battle map ${requestedMapKey} is invalid.`);
  }
  const width = positiveNumber(raw.width, "width");
  const height = positiveNumber(raw.height, "height");
  const spawns = Array.isArray(raw.team_spawns) ? raw.team_spawns : [];
  const spawnBySlot = new Map();
  for (const [index, value] of spawns.entries()) {
    const team = Number(value?.team);
    const slot = Number(value?.slot);
    if (![1, 2].includes(team) || !Number.isInteger(slot) || slot < 1 || slot > 5) {
      throw new Error(`Battle map spawn ${index} has an invalid team or slot.`);
    }
    const key = `${team}:${slot}`;
    if (spawnBySlot.has(key)) {
      throw new Error(`Battle map contains duplicate spawn ${key}.`);
    }
    spawnBySlot.set(key, Object.freeze({
      team,
      slot,
      x: finiteNumber(value.x, `team_spawns[${index}].x`),
      y: finiteNumber(value.y, `team_spawns[${index}].y`),
    }));
  }
  for (const team of [1, 2]) {
    for (let slot = 1; slot <= 5; slot += 1) {
      if (!spawnBySlot.has(`${team}:${slot}`)) {
        throw new Error(`Battle map is missing spawn ${team}:${slot}.`);
      }
    }
  }
  const rules = raw.gameplay_rules ?? {};
  const staticCollisionRectangles = Object.freeze(
    (Array.isArray(raw.static_collision_rectangles)
      ? raw.static_collision_rectangles
      : []).map((value, index) => rectangle(value, `static_collision[${index}]`)),
  );
  const buildingCollisionRectangles = Object.freeze(
    (Array.isArray(raw.building_collision_rectangles)
      ? raw.building_collision_rectangles
      : []).map((value, index) => rectangle(value, `building_collision[${index}]`)),
  );
  const buildings = worldBuildings(raw, buildingCollisionRectangles);
  if (buildings.length !== buildingCollisionRectangles.length) {
    throw new Error("Every authored building collision must belong to one world building.");
  }
  const chiefs = worldChiefs(raw);
  const footpoints = footpointSpawners(raw, buildings);
  return Object.freeze({
    mapKey: String(raw.map_key ?? requestedMapKey),
    width,
    height,
    tankCollisionRadius: positiveNumber(
      raw.tank_collision_radius,
      "tank_collision_radius",
    ),
    tankCollisionCenterOffset: Object.freeze({
      x: finiteNumber(raw.tank_collision_center_offset?.x ?? 0, "offset.x"),
      y: finiteNumber(raw.tank_collision_center_offset?.y ?? 0, "offset.y"),
    }),
    durationSeconds: positiveNumber(rules.duration_seconds, "duration_seconds"),
    scoreLimit: positiveNumber(rules.score_limit, "score_limit"),
    tankKillPoints: positiveNumber(rules.tank_kill_points, "tank_kill_points"),
    chiefKillPoints: positiveNumber(rules.chief_kill_points, "chief_kill_points"),
    spawnBySlot,
    staticCollisionRectangles,
    buildingCollisionRectangles,
    collisionRectangles: Object.freeze([
      ...staticCollisionRectangles,
      ...buildingCollisionRectangles,
    ]),
    worldBuildings: buildings,
    worldChiefs: chiefs,
    footpointSpawners: footpoints,
    footpointRoamRectangle: rectangle(
      raw.footpoint_roam_rectangle,
      "footpoint_roam_rectangle",
    ),
  });
}

export async function loadBattleMap(mapKeyValue) {
  const requestedMapKey = String(mapKeyValue ?? "").trim().toLowerCase();
  const fileName = MAP_FILES[requestedMapKey];
  if (!fileName) {
    throw new Error(`No authoritative battle map registered for ${requestedMapKey}.`);
  }
  if (!cache.has(fileName)) {
    const url = new URL(`../battle_content/maps/${fileName}`, import.meta.url);
    cache.set(fileName, readFile(url, "utf8").then((text) => (
      validateMap(JSON.parse(text), requestedMapKey)
    )));
  }
  return cache.get(fileName);
}

export function registeredBattleMapKeys() {
  return Object.keys(MAP_FILES);
}
