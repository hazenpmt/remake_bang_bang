import assert from "node:assert/strict";
import test from "node:test";
import {
  applyTankSkinCollectionBonus,
  calculateTankSkinCollectionBonus,
  roundTankStatBonus,
} from "../src/tank-skin-bonus.js";
import {
  militaryRankBonusSource,
  militaryRankForStars,
} from "../src/military-rank.js";

const rules = [
  { rule_key: "quality_a", requirement_type: "quality", required_quality: "A", hit_points_percent: 2 },
  { rule_key: "quality_s", requirement_type: "quality", required_quality: "S", attack_percent: 2 },
  { rule_key: "quality_ss", requirement_type: "quality", required_quality: "SS", hit_points_percent: 6 },
  { rule_key: "quality_sss", requirement_type: "quality", required_quality: "SSS", attack_percent: 6 },
  {
    rule_key: "distinct_2",
    requirement_type: "distinct_quality_count",
    required_distinct_quality_count: 2,
    hit_points_percent: 2,
    attack_percent: 2,
    frame_tier: "purple",
  },
  {
    rule_key: "distinct_3_sss",
    requirement_type: "distinct_quality_count",
    required_distinct_quality_count: 3,
    requires_sss: true,
    frame_tier: "orange",
  },
  {
    rule_key: "distinct_4",
    requirement_type: "distinct_quality_count",
    required_distinct_quality_count: 4,
    revive_speed_percent: 100,
    revive_duration_seconds: 3,
  },
];

test("real stat bonuses round down at 0.5 and up only above 0.5", () => {
  assert.equal(roundTankStatBonus(0.49), 0);
  assert.equal(roundTankStatBonus(0.5), 0);
  assert.equal(roundTankStatBonus(1.5), 1);
  assert.equal(roundTankStatBonus(1.500001), 2);
  assert.equal(roundTankStatBonus(1.6), 2);
  assert.equal(roundTankStatBonus(23.8), 24);
  assert.equal(roundTankStatBonus(232.5), 232);
});

test("skin collection starts at zero when no quality requirement is met", () => {
  const bonus = calculateTankSkinCollectionBonus(
    [{ quality_key: "", owned: true }],
    rules,
  );
  assert.equal(bonus.hit_points_percent, 0);
  assert.equal(bonus.total_tc_percent, 0);
  assert.equal(bonus.frame_tier, "");
  assert.equal(bonus.requirements.every((rule) => !rule.completed), true);
});

test("skin frame tier progresses independently for each tank", () => {
  const bonusFor = (qualities) => calculateTankSkinCollectionBonus(
    qualities.map((quality_key) => ({ quality_key, owned: true })),
    rules,
  );
  assert.equal(bonusFor(["A"]).frame_tier, "");
  assert.equal(bonusFor(["A", "S"]).frame_tier, "purple");
  assert.equal(bonusFor(["A", "S", "SS"]).frame_tier, "purple");
  assert.equal(bonusFor(["A", "S", "SSS"]).frame_tier, "orange");

  const firstTank = bonusFor(["A", "S", "SSS"]);
  const secondTank = bonusFor(["A"]);
  assert.equal(firstTank.frame_tier, "orange");
  assert.equal(secondTank.frame_tier, "");
});

test("owned qualities activate real cumulative tank stats", () => {
  const tank = {
    hit_points: 1000,
    basic_attack_damage: 200,
    skins: ["A", "S", "SS", "SSS"].map((quality_key) => ({
      quality_key,
      owned: true,
    })),
  };
  applyTankSkinCollectionBonus(tank, rules);
  assert.equal(tank.skin_collection_bonus.hit_points_percent, 10);
  assert.equal(tank.skin_collection_bonus.attack_percent, 10);
  assert.equal(tank.skin_collection_bonus.frame_tier, "orange");
  assert.equal(tank.skin_collection_bonus.revive_speed_percent, 100);
  assert.equal(tank.skin_collection_bonus.revive_duration_seconds, 3);
  assert.equal(tank.base_hit_points, 1000);
  assert.equal(tank.hit_points, 1100);
  assert.equal(tank.base_basic_attack_damage, 200);
  assert.equal(tank.basic_attack_damage, 220);
  assert.deepEqual(tank.base_stats, {
    hit_points: 1000,
    basic_attack_damage: 200,
    penetration: null,
    physical_armor: null,
    energy_shield: null,
    move_speed: null,
    fire_rate: null,
    attack_range: null,
    critical_chance_percent: null,
    critical_damage_percent: null,
  });
  assert.equal(tank.stat_bonuses.hit_points, 100);
  assert.equal(tank.stat_bonuses.basic_attack_damage, 20);
  assert.equal(tank.stat_bonus_sources[0].source_key, "skin_collection");
});

test("real bonus sources are summed separately from verified base stats", () => {
  const tank = {
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
    skins: [],
    stat_bonus_sources: [{
      source_key: "test_rank_source",
      hit_points: 48,
      basic_attack_damage: 1.6,
      penetration: 3.2,
      physical_armor: 1.6,
      energy_shield: 3.2,
      move_speed: 9,
      fire_rate: 8,
      attack_range: 7,
    }],
  };

  applyTankSkinCollectionBonus(tank, rules);

  assert.deepEqual(tank.base_stats, {
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
  });
  assert.deepEqual(tank.stat_bonuses, {
    hit_points: 48,
    basic_attack_damage: 2,
    penetration: 3,
    physical_armor: 2,
    energy_shield: 3,
    move_speed: 0,
    fire_rate: 0,
    attack_range: 0,
    critical_chance_percent: 0,
    critical_damage_percent: 0,
  });
  assert.deepEqual(tank.effective_stats, {
    hit_points: 2373,
    basic_attack_damage: 240,
    penetration: 33,
    physical_armor: 152,
    energy_shield: 153,
    move_speed: 170,
    fire_rate: 66,
    attack_range: 480,
    critical_chance_percent: 5,
    critical_damage_percent: 150,
  });
});

test("green tank bonus combines exact military-rank values and skin percentages of base stats", () => {
  const tank = {
    hit_points: 2325,
    basic_attack_damage: 238,
    penetration: 30,
    physical_armor: 150,
    energy_shield: 150,
    skins: [
      { quality_key: "A", owned: true },
      { quality_key: "S", owned: true },
    ],
    stat_bonus_sources: [
      militaryRankBonusSource(militaryRankForStars(1)),
    ],
  };

  applyTankSkinCollectionBonus(tank, rules);

  assert.equal(tank.skin_collection_bonus.hit_points_percent, 4);
  assert.equal(tank.skin_collection_bonus.attack_percent, 4);
  assert.equal(tank.stat_bonus_sources[0].source_key, "skin_collection");
  assert.equal(tank.stat_bonus_sources[0].hit_points, 93);
  assert.equal(tank.stat_bonus_sources[0].basic_attack_damage, 9.52);
  assert.deepEqual(tank.stat_bonuses, {
    hit_points: 93,
    basic_attack_damage: 10,
    penetration: 0,
    physical_armor: 2,
    energy_shield: 0,
    move_speed: 0,
    fire_rate: 0,
    attack_range: 0,
    critical_chance_percent: 0,
    critical_damage_percent: 0,
  });
  assert.deepEqual(tank.effective_stats, {
    hit_points: 2418,
    basic_attack_damage: 248,
    penetration: 30,
    physical_armor: 152,
    energy_shield: 150,
    move_speed: null,
    fire_rate: null,
    attack_range: null,
    critical_chance_percent: null,
    critical_damage_percent: null,
  });
});
