import assert from "node:assert/strict";
import test from "node:test";
import {
  MILITARY_RANKS,
  applyMilitaryRankCooldowns,
  buildMilitaryRankSummary,
  calculateMilitaryRankStars,
  militaryRankBonusSource,
  militaryRankForStars,
} from "../src/military-rank.js";

test("rank thresholds follow all five original military-rank pages", () => {
  assert.deepEqual(
    MILITARY_RANKS.map((rank) => rank.required_stars),
    [
      0, 5, 10, 15, 20, 25, 30, 35,
      40, 45, 50, 55, 60, 65, 70, 75,
      85, 95, 105, 115, 125, 135, 150, 165,
      180, 195, 210, 225, 245, 265, 285, 305,
      325, 345, 370, 395, 420, 450, 480, 510,
    ],
  );
});

test("later ranks use the non-linear original thresholds when promoting", () => {
  const beforeThuongTaCap2 = militaryRankForStars(669);
  assert.equal(beforeThuongTaCap2.current.rank_id, 16);
  assert.equal(beforeThuongTaCap2.progress_stars, 84);
  assert.equal(beforeThuongTaCap2.progress_required, 85);

  const thuongTaCap2 = militaryRankForStars(670);
  assert.equal(thuongTaCap2.current.rank_id, 17);
  assert.equal(thuongTaCap2.progress_stars, 1);
  assert.equal(thuongTaCap2.progress_required, 95);
});

test("one owned level-1 tank grants exactly one military-rank star", () => {
  assert.equal(calculateMilitaryRankStars([{ tank_level: 1 }]), 1);
});

test("each tank level and each additional owned tank contributes one star", () => {
  assert.equal(
    calculateMilitaryRankStars([
      { tank_level: 6 },
      { tank_level: 3 },
      { tank_level: 1 },
    ]),
    10,
  );
});

test("one star opens exactly one Binh nhi attribute", () => {
  const rank = militaryRankForStars(1);
  assert.equal(rank.current.rank_id, 1);
  assert.equal(rank.progress_stars, 1);
  assert.equal(rank.progress_required, 5);
  assert.equal(rank.attribute_unlock_count, 1);
});

test("a completed bar rolls immediately to one star in the next rank", () => {
  const haSi = militaryRankForStars(5);
  assert.equal(haSi.current.rank_id, 2);
  assert.equal(haSi.progress_stars, 1);
  assert.equal(haSi.progress_required, 10);
  assert.equal(haSi.attribute_unlock_count, 0);

  const trungSi = militaryRankForStars(14);
  assert.equal(trungSi.current.rank_id, 3);
  assert.equal(trungSi.progress_stars, 1);
  assert.equal(trungSi.progress_required, 15);
});

test("attribute costs rise by one star per slot for each rank", () => {
  assert.equal(militaryRankForStars(4).attribute_unlock_count, 4);
  assert.equal(militaryRankForStars(6).attribute_unlock_count, 1);
  assert.equal(militaryRankForStars(7).attribute_unlock_count, 1);
  assert.equal(militaryRankForStars(8).attribute_unlock_count, 2);
});

test("summary includes authoritative owned-tank count", () => {
  const summary = buildMilitaryRankSummary([
    { tank_level: 4 },
    { tank_level: 1 },
  ]);
  assert.equal(summary.stars, 5);
  assert.equal(summary.owned_tank_count, 2);
  assert.equal(summary.current.rank_id, 2);
});

test("opened attributes produce real cumulative tank bonuses", () => {
  const rank = militaryRankForStars(8);
  assert.deepEqual(militaryRankBonusSource(rank), {
    source_key: "military_rank",
    hit_points: 24,
    basic_attack_damage: 1.6,
    penetration: 1.6,
    physical_armor: 3.2,
    energy_shield: 3.2,
  });
});

test("every four unlocked ranks adds 0.5 percent cooldown reduction", () => {
  const thuongSi = militaryRankForStars(28);
  assert.equal(thuongSi.current.rank_id, 4);
  assert.equal(thuongSi.cooldown_reduction_percent, 0.5);
  assert.equal(thuongSi.next_cooldown_milestone.rank_id, 8);

  const skills = applyMilitaryRankCooldowns(
    [{ cooldown_ms: 20000 }],
    thuongSi.cooldown_reduction_percent,
  );
  assert.equal(skills[0].base_cooldown_ms, 20000);
  assert.equal(skills[0].cooldown_ms, 19900);
});
