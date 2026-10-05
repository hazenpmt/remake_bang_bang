import { createHash } from "node:crypto";

export const BATTLE_PROTOCOL_VERSION = 2;
export const BATTLE_INPUT_LEASE_MS = 300;
export const BATTLE_RESPAWN_MS = 10_000;
export const BATTLE_RESPAWN_INVULNERABILITY_MS = 1_500;
export const BATTLE_SHIELD_RECHARGE_MS = 15_000;
export const BATTLE_ASSIST_WINDOW_MS = 6_000;

const COMMAND_TYPES = new Set([
  "move",
  "basic_attack",
  "skill",
  "skill_aim",
  "skill_cancel",
  "respawn",
  "surrender",
]);

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function finiteNumber(value, field) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw new TypeError(`${field} must be a finite number.`);
  }
  return number;
}

function stableValue(value) {
  if (Array.isArray(value)) {
    return value.map(stableValue);
  }
  if (plainObject(value)) {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, stableValue(value[key])]),
    );
  }
  return value;
}

export function battleCommandHash(value) {
  return createHash("sha256")
    .update(JSON.stringify(stableValue(value)))
    .digest("hex");
}

export function normalizeVector(xValue, yValue, allowZero = false) {
  const x = finiteNumber(xValue, "x");
  const y = finiteNumber(yValue, "y");
  const length = Math.hypot(x, y);
  if (length <= 0.000001) {
    if (allowZero) {
      return { x: 0, y: 0 };
    }
    throw new TypeError("Direction cannot be zero.");
  }
  return { x: x / length, y: y / length };
}

export function validateBattleCommandRequest(body) {
  if (!plainObject(body) || !plainObject(body.command)) {
    throw new TypeError("Battle command body is invalid.");
  }
  const sequence = Number(body.sequence);
  if (!Number.isSafeInteger(sequence) || sequence <= 0) {
    throw new TypeError("Battle command sequence must be a positive safe integer.");
  }
  const type = String(body.command.type ?? "").trim().toLowerCase();
  if (!COMMAND_TYPES.has(type)) {
    throw new TypeError("Battle command type is invalid.");
  }
  const command = { type };
  if (type === "move") {
    const direction = normalizeVector(
      body.command.x ?? 0,
      body.command.y ?? 0,
      true,
    );
    command.x = direction.x;
    command.y = direction.y;
  } else if (["basic_attack", "skill", "skill_aim"].includes(type)) {
    command.target_x = finiteNumber(body.command.target_x, "target_x");
    command.target_y = finiteNumber(body.command.target_y, "target_y");
    if (type === "skill") {
      const slot = Number(body.command.slot);
      if (!Number.isInteger(slot) || slot < 1 || slot > 3) {
        throw new TypeError("Battle skill slot must be 1, 2, or 3.");
      }
      command.slot = slot;
    }
  }
  return {
    sequence,
    command,
    payloadHash: battleCommandHash(command),
  };
}

function circleIntersectsRectangle(center, radius, rectangle) {
  const nearestX = Math.max(
    rectangle.x,
    Math.min(center.x, rectangle.x + rectangle.width),
  );
  const nearestY = Math.max(
    rectangle.y,
    Math.min(center.y, rectangle.y + rectangle.height),
  );
  const deltaX = center.x - nearestX;
  const deltaY = center.y - nearestY;
  return deltaX * deltaX + deltaY * deltaY < radius * radius;
}

function clampTankPosition(position, map) {
  const offset = map.tankCollisionCenterOffset;
  const radius = map.tankCollisionRadius;
  return {
    x: Math.max(radius - offset.x, Math.min(
      position.x,
      map.width - radius - offset.x,
    )),
    y: Math.max(radius - offset.y, Math.min(
      position.y,
      map.height - radius - offset.y,
    )),
  };
}

export function tankCanOccupy(position, map) {
  const center = {
    x: position.x + map.tankCollisionCenterOffset.x,
    y: position.y + map.tankCollisionCenterOffset.y,
  };
  return !map.collisionRectangles.some(
    (rectangle) => circleIntersectsRectangle(
      center,
      map.tankCollisionRadius,
      rectangle,
    ),
  );
}

function safeMovementFraction(start, motion, map) {
  const finish = clampTankPosition({ x: start.x + motion.x, y: start.y + motion.y }, map);
  if (tankCanOccupy(finish, map)) {
    return 1;
  }
  let safe = 0;
  let blocked = 1;
  for (let iteration = 0; iteration < 12; iteration += 1) {
    const middle = (safe + blocked) / 2;
    const candidate = clampTankPosition({
      x: start.x + motion.x * middle,
      y: start.y + motion.y * middle,
    }, map);
    if (tankCanOccupy(candidate, map)) {
      safe = middle;
    } else {
      blocked = middle;
    }
  }
  return safe;
}

export function moveTankWithCollision(startValue, motionValue, map) {
  let position = clampTankPosition({
    x: finiteNumber(startValue.x, "position.x"),
    y: finiteNumber(startValue.y, "position.y"),
  }, map);
  const motion = {
    x: finiteNumber(motionValue.x, "motion.x"),
    y: finiteNumber(motionValue.y, "motion.y"),
  };
  const length = Math.hypot(motion.x, motion.y);
  if (length <= 0.0001) {
    return position;
  }
  // A step must remain smaller than the collision diameter. Otherwise both
  // endpoints could be valid on opposite sides of a thin obstacle and the
  // endpoint/binary test would tunnel through it.
  const maximumStep = Math.max(
    0.25,
    Math.min(12, Number(map.tankCollisionRadius) * 0.5),
  );
  const steps = Math.max(1, Math.ceil(length / maximumStep));
  const step = { x: motion.x / steps, y: motion.y / steps };
  for (let index = 0; index < steps; index += 1) {
    const fraction = safeMovementFraction(position, step, map);
    position = clampTankPosition({
      x: position.x + step.x * fraction,
      y: position.y + step.y * fraction,
    }, map);
    if (fraction >= 0.999999) {
      continue;
    }
    // Preserve the unblocked component after contact so diagonal input slides
    // along authored axis-aligned walls instead of sticking at the first hit.
    // Each axis still passes through the same swept collision guard, so this
    // cannot be used to tunnel through corners or exceed server-owned speed.
    const remaining = {
      x: step.x * (1 - fraction),
      y: step.y * (1 - fraction),
    };
    const axes = Math.abs(remaining.x) >= Math.abs(remaining.y)
      ? [{ x: remaining.x, y: 0 }, { x: 0, y: remaining.y }]
      : [{ x: 0, y: remaining.y }, { x: remaining.x, y: 0 }];
    for (const axisMotion of axes) {
      if (Math.hypot(axisMotion.x, axisMotion.y) <= 0.0001) {
        continue;
      }
      const axisFraction = safeMovementFraction(position, axisMotion, map);
      position = clampTankPosition({
        x: position.x + axisMotion.x * axisFraction,
        y: position.y + axisMotion.y * axisFraction,
      }, map);
    }
  }
  return position;
}

export function segmentCircleFraction(start, finish, center, radius) {
  const dx = finish.x - start.x;
  const dy = finish.y - start.y;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared <= 0.000001) {
    return Infinity;
  }
  const projection = Math.max(0, Math.min(1,
    ((center.x - start.x) * dx + (center.y - start.y) * dy) / lengthSquared,
  ));
  const closestX = start.x + dx * projection;
  const closestY = start.y + dy * projection;
  return Math.hypot(center.x - closestX, center.y - closestY) <= radius
    ? projection
    : Infinity;
}

export function segmentRectangleFraction(start, finish, rectangle) {
  const deltaX = finish.x - start.x;
  const deltaY = finish.y - start.y;
  let minimum = 0;
  let maximum = 1;
  for (const [origin, delta, low, high] of [
    [start.x, deltaX, rectangle.x, rectangle.x + rectangle.width],
    [start.y, deltaY, rectangle.y, rectangle.y + rectangle.height],
  ]) {
    if (Math.abs(delta) <= 0.000001) {
      if (origin < low || origin > high) {
        return Infinity;
      }
      continue;
    }
    const first = (low - origin) / delta;
    const second = (high - origin) / delta;
    minimum = Math.max(minimum, Math.min(first, second));
    maximum = Math.min(maximum, Math.max(first, second));
    if (minimum > maximum) {
      return Infinity;
    }
  }
  return minimum >= 0 && minimum <= 1 ? minimum : Infinity;
}

export function firstTerrainFraction(start, finish, map) {
  return map.collisionRectangles.reduce(
    (best, rectangle) => Math.min(
      best,
      segmentRectangleFraction(start, finish, rectangle),
    ),
    Infinity,
  );
}

export function firstEnemyOnSegment(attacker, entities, finish, map, radius = 36) {
  const start = { x: Number(attacker.position_x), y: Number(attacker.position_y) };
  const terrainFraction = firstTerrainFraction(start, finish, map);
  let best = null;
  let bestFraction = terrainFraction;
  for (const target of entities) {
    if (
      target === attacker
      || Number(target.team_no) === Number(attacker.team_no)
      || target.dead
    ) {
      continue;
    }
    const fraction = segmentCircleFraction(start, finish, {
      x: Number(target.position_x),
      y: Number(target.position_y),
    }, radius);
    if (fraction < bestFraction) {
      best = target;
      bestFraction = fraction;
    }
  }
  return { target: best, fraction: bestFraction, terrainFraction };
}

export function enemiesInRadius(attacker, entities, center, radius) {
  return entities.filter((target) => (
    target !== attacker
    && Number(target.team_no) !== Number(attacker.team_no)
    && !target.dead
    && Math.hypot(
      Number(target.position_x) - center.x,
      Number(target.position_y) - center.y,
    ) <= radius
  ));
}

export function enemiesInLine(attacker, entities, finish, halfWidth, map) {
  const start = { x: Number(attacker.position_x), y: Number(attacker.position_y) };
  const terrainFraction = firstTerrainFraction(start, finish, map);
  return entities.filter((target) => {
    if (
      target === attacker
      || Number(target.team_no) === Number(attacker.team_no)
      || target.dead
    ) {
      return false;
    }
    const fraction = segmentCircleFraction(start, finish, {
      x: Number(target.position_x),
      y: Number(target.position_y),
    }, halfWidth + 36);
    return fraction < terrainFraction;
  });
}

export function calculateBattleDamage(attacker, target, rawDamage, criticalRoll) {
  const safeRawDamage = Math.max(0, Number(rawDamage) || 0);
  const chance = Math.max(0, Math.min(
    10_000,
    Number(attacker.critical_chance_basis_points) || 0,
  ));
  const critical = Number(criticalRoll) < chance;
  const criticalMultiplier = Math.max(
    1,
    (Number(attacker.critical_damage_basis_points) || 10_000) / 10_000,
  );
  const adjusted = safeRawDamage * (critical ? criticalMultiplier : 1);
  const damageType = attacker.damage_type === "energy" ? "energy" : "physical";
  const baseDefence = Number(
    damageType === "energy" ? target.energy_shield : target.physical_armor,
  ) || 0;
  const defence = Math.max(
    0,
    baseDefence - Math.max(0, Number(attacker.penetration) || 0),
  );
  return {
    critical,
    damage: Math.max(0, Math.round(adjusted * 1000 / (1000 + defence))),
  };
}
