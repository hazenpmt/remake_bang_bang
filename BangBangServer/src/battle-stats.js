import {
  applyMilitaryRankCooldowns,
  buildMilitaryRankSummary,
  militaryRankBonusSource,
} from "./military-rank.js";
import { applyTankSkinCollectionBonus } from "./tank-skin-bonus.js";

const DEFAULT_STATS = Object.freeze({
  hit_points: 2325,
  basic_attack_damage: 238,
  penetration: 30,
  physical_armor: 150,
  energy_shield: 150,
  move_speed: 170,
  fire_rate: 66,
  attack_range: 480,
  critical_chance_percent: 5,
  critical_damage_percent: 150,
  damage_type: "physical",
});

const DEFAULT_SKILL_COOLDOWNS = Object.freeze([6000, 8000, 20000]);

function finiteOr(value, fallback) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

async function tankRecord(client, participant) {
  const result = await client.query(
    `SELECT tank.id AS tank_id,
            tank.tank_key,
            tank.battle_kit_key,
            tank.damage_type,
            stats.hit_points,
            stats.basic_attack_damage,
            stats.penetration,
            stats.physical_armor,
            stats.energy_shield,
            stats.move_speed,
            stats.fire_rate,
            stats.attack_range,
            (stats.critical_chance_basis_points::numeric / 100)::float8
                AS critical_chance_percent,
            (stats.critical_damage_basis_points::numeric / 100)::float8
                AS critical_damage_percent
       FROM tanks tank
       LEFT JOIN tank_level_stats stats
              ON stats.tank_id = tank.id
             AND stats.level = $2
      WHERE tank.tank_key = $1
        AND tank.enabled`,
    [participant.tank_key, participant.tank_level],
  );
  return result.rows[0] ?? {
    tank_id: null,
    tank_key: participant.tank_key || "gangtiexia03",
    battle_kit_key: null,
    ...DEFAULT_STATS,
  };
}

async function playerBonusData(client, accountId, tankId) {
  if (!accountId || !tankId) {
    return { skins: [], sources: [], rankSource: null };
  }
  const skinResult = await client.query(
      `SELECT skin.quality_key,
              TRUE AS owned
         FROM player_tank_skins owned
         JOIN tank_skins skin ON skin.id = owned.tank_skin_id
        WHERE owned.account_id = $1
          AND skin.tank_id = $2
          AND skin.enabled`,
      [accountId, tankId],
    );
  const sourceResult = await client.query(
      `SELECT source_key,
              hit_points,
              basic_attack_damage,
              penetration,
              physical_armor,
              energy_shield
         FROM player_tank_stat_bonuses
        WHERE account_id = $1
          AND tank_id = $2
          AND source_key <> 'military_rank'`,
      [accountId, tankId],
    );
  const rankResult = await client.query(
      `SELECT level AS tank_level
         FROM player_tanks
        WHERE account_id = $1`,
      [accountId],
    );
  const rank = buildMilitaryRankSummary(rankResult.rows);
  return {
    skins: skinResult.rows,
    sources: sourceResult.rows,
    rank,
    rankSource: militaryRankBonusSource(rank),
  };
}

export async function loadBattleParticipantStats(client, participant) {
  const base = await tankRecord(client, participant);
  const ruleResult = await client.query(
      `SELECT rule_key,
              requirement_type,
              required_quality,
              required_distinct_quality_count,
              requires_sss,
              hit_points_percent,
              attack_percent,
              frame_tier,
              revive_speed_percent,
              revive_duration_seconds
         FROM tank_skin_collection_rules
        WHERE enabled
        ORDER BY sort_order, id`,
    );
  const bonus = await playerBonusData(client, participant.account_id, base.tank_id);
  const tank = {
    ...base,
    skins: bonus.skins,
    stat_bonus_sources: [
      ...bonus.sources,
      ...(bonus.rankSource ? [bonus.rankSource] : []),
    ],
  };
  applyTankSkinCollectionBonus(tank, ruleResult.rows);

  const skillResult = base.tank_id
    ? await client.query(
      `SELECT slot_index, cooldown_ms
         FROM tank_skills
        WHERE tank_id = $1
        ORDER BY slot_index`,
      [base.tank_id],
    )
    : { rows: [] };
  const skills = applyMilitaryRankCooldowns(
    skillResult.rows,
    bonus.rank?.cooldown_reduction_percent ?? 0,
  );
  const skillCooldownMs = [...DEFAULT_SKILL_COOLDOWNS];
  for (const skill of skills) {
    const slot = Number(skill.slot_index) - 1;
    const cooldown = Number(skill.cooldown_ms);
    if (slot >= 0 && slot < skillCooldownMs.length && cooldown > 0) {
      skillCooldownMs[slot] = Math.max(500, Math.round(cooldown));
    }
  }

  return {
    tankKey: String(base.tank_key ?? participant.tank_key ?? "gangtiexia03"),
    battleKitKey: base.battle_kit_key == null
      ? null
      : String(base.battle_kit_key),
    hitPoints: Math.max(1, Math.round(finiteOr(tank.hit_points, DEFAULT_STATS.hit_points))),
    basicAttackDamage: Math.max(0, finiteOr(
      tank.basic_attack_damage,
      DEFAULT_STATS.basic_attack_damage,
    )),
    penetration: Math.max(0, finiteOr(tank.penetration, DEFAULT_STATS.penetration)),
    physicalArmor: Math.max(0, finiteOr(
      tank.physical_armor,
      DEFAULT_STATS.physical_armor,
    )),
    energyShield: Math.max(0, finiteOr(
      tank.energy_shield,
      DEFAULT_STATS.energy_shield,
    )),
    moveSpeed: Math.max(0, finiteOr(tank.move_speed, DEFAULT_STATS.move_speed)),
    fireRate: Math.max(1, finiteOr(tank.fire_rate, DEFAULT_STATS.fire_rate)),
    attackRange: Math.max(1, finiteOr(tank.attack_range, DEFAULT_STATS.attack_range)),
    criticalChanceBasisPoints: Math.round(Math.max(0, Math.min(
      100,
      finiteOr(tank.critical_chance_percent, DEFAULT_STATS.critical_chance_percent),
    )) * 100),
    criticalDamageBasisPoints: Math.round(Math.max(
      100,
      finiteOr(tank.critical_damage_percent, DEFAULT_STATS.critical_damage_percent),
    ) * 100),
    damageType: base.damage_type === "energy" ? "energy" : "physical",
    skillCooldownMs,
  };
}
