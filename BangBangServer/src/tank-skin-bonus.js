function nonNegativeNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function normalizedQuality(value) {
  const quality = typeof value === "string" ? value.trim().toUpperCase() : "";
  return ["A", "S", "SS", "SSS"].includes(quality) ? quality : "";
}

function finiteStat(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function roundTankStatBonus(value) {
  const safeValue = nonNegativeNumber(value);
  const lowerValue = Math.floor(safeValue);
  return safeValue - lowerValue > 0.5 ? lowerValue + 1 : lowerValue;
}

const TANK_STAT_KEYS = [
  "hit_points",
  "basic_attack_damage",
  "penetration",
  "physical_armor",
  "energy_shield",
  "move_speed",
  "fire_rate",
  "attack_range",
  "critical_chance_percent",
  "critical_damage_percent",
];

const BONUS_ELIGIBLE_STAT_KEYS = [
  "hit_points",
  "basic_attack_damage",
  "penetration",
  "physical_armor",
  "energy_shield",
];

function emptyStatValues() {
  return Object.fromEntries(TANK_STAT_KEYS.map((key) => [key, 0]));
}

function normalizedStatSource(source) {
  const result = {
    source_key: typeof source?.source_key === "string"
      ? source.source_key.trim()
      : "",
    ...emptyStatValues(),
  };
  for (const key of BONUS_ELIGIBLE_STAT_KEYS) {
    result[key] = nonNegativeNumber(source?.[key]);
  }
  return result;
}

export function calculateTankSkinCollectionBonus(skins = [], rules = []) {
  const ownedQualities = new Set(
    skins
      .filter((skin) => skin?.owned === true)
      .map((skin) => normalizedQuality(skin?.quality_key))
      .filter(Boolean),
  );
  const requirements = [];
  let hitPointsPercent = 0;
  let attackPercent = 0;
  let frameTier = "";
  let reviveSpeedPercent = 0;
  let reviveDurationSeconds = 0;

  for (const rule of rules) {
    let completed = false;
    if (rule.requirement_type === "quality") {
      completed = ownedQualities.has(normalizedQuality(rule.required_quality));
    } else if (rule.requirement_type === "distinct_quality_count") {
      completed = ownedQualities.size >= nonNegativeNumber(
        rule.required_distinct_quality_count,
      );
      if (rule.requires_sss === true) {
        completed = completed && ownedQualities.has("SSS");
      }
    }

    const requirement = {
      rule_key: String(rule.rule_key ?? ""),
      completed,
      required_quality: normalizedQuality(rule.required_quality),
      required_distinct_quality_count: nonNegativeNumber(
        rule.required_distinct_quality_count,
      ),
      requires_sss: rule.requires_sss === true,
      hit_points_percent: nonNegativeNumber(rule.hit_points_percent),
      attack_percent: nonNegativeNumber(rule.attack_percent),
      frame_tier: typeof rule.frame_tier === "string" ? rule.frame_tier : "",
      revive_speed_percent: nonNegativeNumber(rule.revive_speed_percent),
      revive_duration_seconds: nonNegativeNumber(rule.revive_duration_seconds),
    };
    requirements.push(requirement);

    if (!completed) {
      continue;
    }
    hitPointsPercent += requirement.hit_points_percent;
    attackPercent += requirement.attack_percent;
    if (requirement.frame_tier) {
      frameTier = requirement.frame_tier;
    }
    reviveSpeedPercent += requirement.revive_speed_percent;
    reviveDurationSeconds = Math.max(
      reviveDurationSeconds,
      requirement.revive_duration_seconds,
    );
  }

  return {
    owned_quality_count: ownedQualities.size,
    owned_qualities: [...ownedQualities],
    hit_points_percent: hitPointsPercent,
    attack_percent: attackPercent,
    total_tc_percent: attackPercent,
    frame_tier: frameTier,
    revive_speed_percent: reviveSpeedPercent,
    revive_duration_seconds: reviveDurationSeconds,
    requirements,
  };
}

export function applyTankSkinCollectionBonus(tank, rules = []) {
  const bonus = calculateTankSkinCollectionBonus(tank?.skins, rules);
  tank.skin_collection_bonus = bonus;

  const baseStats = {};
  for (const key of TANK_STAT_KEYS) {
    baseStats[key] = finiteStat(tank?.[key]);
  }
  const collectionSource = {
    source_key: "skin_collection",
    ...emptyStatValues(),
  };
  if (baseStats.hit_points !== null) {
    collectionSource.hit_points =
      baseStats.hit_points * bonus.hit_points_percent / 100;
  }
  if (baseStats.basic_attack_damage !== null) {
    collectionSource.basic_attack_damage =
      baseStats.basic_attack_damage * bonus.attack_percent / 100;
  }

  const sourceRows = Array.isArray(tank?.stat_bonus_sources)
    ? tank.stat_bonus_sources
    : [];
  const statBonusSources = [
    collectionSource,
    ...sourceRows
      .map(normalizedStatSource)
      .filter((source) => (
        source.source_key
        && source.source_key !== "skin_collection"
      )),
  ];
  const statBonuses = emptyStatValues();
  for (const source of statBonusSources) {
    for (const key of TANK_STAT_KEYS) {
      statBonuses[key] += source[key];
    }
  }
  for (const key of BONUS_ELIGIBLE_STAT_KEYS) {
    statBonuses[key] = roundTankStatBonus(statBonuses[key]);
  }

  const effectiveStats = {};
  for (const key of TANK_STAT_KEYS) {
    const baseValue = baseStats[key];
    effectiveStats[key] = (
      baseValue === null ? null : baseValue + statBonuses[key]
    );
    tank[`base_${key}`] = baseValue;
    if (effectiveStats[key] !== null) {
      tank[key] = effectiveStats[key];
    }
  }
  tank.base_stats = baseStats;
  tank.stat_bonus_sources = statBonusSources;
  tank.stat_bonuses = statBonuses;
  tank.effective_stats = effectiveStats;
  return tank;
}
