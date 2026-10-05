export const MILITARY_RANKS = Object.freeze([
  { rank_id: 1, required_stars: 0, name: "Binh nhì", icon: "Junxian01.png" },
  { rank_id: 2, required_stars: 5, name: "Hạ Sĩ", icon: "Junxian02.png" },
  { rank_id: 3, required_stars: 10, name: "Trung Sĩ", icon: "Junxian03.png" },
  { rank_id: 4, required_stars: 15, name: "Thượng Sĩ", icon: "Junxian04.png" },
  { rank_id: 5, required_stars: 20, name: "Chuẩn Úy", icon: "Junxian05.png" },
  { rank_id: 6, required_stars: 25, name: "Thiếu Úy", icon: "Junxian06.png" },
  { rank_id: 7, required_stars: 30, name: "Trung Úy", icon: "Junxian07.png" },
  { rank_id: 8, required_stars: 35, name: "Thượng Úy", icon: "Junxian08.png" },
  { rank_id: 9, required_stars: 40, name: "Đại Úy", icon: "Junxian09.png" },
  { rank_id: 10, required_stars: 45, name: "Thiếu Tá", icon: "Junxian10.png" },
  { rank_id: 11, required_stars: 50, name: "Thiếu Tá Cấp 2", icon: "Junxian11.png" },
  { rank_id: 12, required_stars: 55, name: "Thiếu Tá Cấp 3", icon: "Junxian12.png" },
  { rank_id: 13, required_stars: 60, name: "Trung Tá", icon: "Junxian13.png" },
  { rank_id: 14, required_stars: 65, name: "Trung Tá Cấp 2", icon: "Junxian14.png" },
  { rank_id: 15, required_stars: 70, name: "Trung Tá Cấp 3", icon: "Junxian15.png" },
  { rank_id: 16, required_stars: 75, name: "Thượng Tá", icon: "Junxian16.png" },
  { rank_id: 17, required_stars: 85, name: "Thượng Tá Cấp 2", icon: "Junxian17.png" },
  { rank_id: 18, required_stars: 95, name: "Thượng Tá Cấp 3", icon: "Junxian18.png" },
  { rank_id: 19, required_stars: 105, name: "Đại Tá", icon: "Junxian19.png" },
  { rank_id: 20, required_stars: 115, name: "Đại Tá Cấp 2", icon: "Junxian20.png" },
  { rank_id: 21, required_stars: 125, name: "Đại Tá Cấp 3", icon: "Junxian21.png" },
  { rank_id: 22, required_stars: 135, name: "Chuẩn Tướng", icon: "Junxian22.png" },
  { rank_id: 23, required_stars: 150, name: "Chuẩn Tướng Cấp 2", icon: "Junxian23.png" },
  { rank_id: 24, required_stars: 165, name: "Chuẩn Tướng Cấp 3", icon: "Junxian24.png" },
  { rank_id: 25, required_stars: 180, name: "Thiếu Tướng", icon: "Junxian25.png" },
  { rank_id: 26, required_stars: 195, name: "Thiếu Tướng Cấp 2", icon: "Junxian26.png" },
  { rank_id: 27, required_stars: 210, name: "Thiếu Tướng Cấp 3", icon: "Junxian27.png" },
  { rank_id: 28, required_stars: 225, name: "Trung Tướng", icon: "Junxian28.png" },
  { rank_id: 29, required_stars: 245, name: "Trung Tướng Cấp 2", icon: "Junxian29.png" },
  { rank_id: 30, required_stars: 265, name: "Trung Tướng Cấp 3", icon: "Junxian30.png" },
  { rank_id: 31, required_stars: 285, name: "Thượng Tướng", icon: "Junxian31.png" },
  { rank_id: 32, required_stars: 305, name: "Thượng Tướng Cấp 2", icon: "Junxian32.png" },
  { rank_id: 33, required_stars: 325, name: "Thượng Tướng Cấp 3", icon: "Junxian33.png" },
  { rank_id: 34, required_stars: 345, name: "Đại Tướng Cấp 1", icon: "Junxian34.png" },
  { rank_id: 35, required_stars: 370, name: "Đại Tướng Cấp 2", icon: "Junxian35.png" },
  { rank_id: 36, required_stars: 395, name: "Đại Tướng Cấp 3", icon: "Junxian36.png" },
  { rank_id: 37, required_stars: 420, name: "Nguyên Soái Cấp 1", icon: "Junxian37.png" },
  { rank_id: 38, required_stars: 450, name: "Nguyên Soái Cấp 2", icon: "Junxian38.png" },
  { rank_id: 39, required_stars: 480, name: "Nguyên Soái Cấp 3", icon: "Junxian39.png" },
  { rank_id: 40, required_stars: 510, name: "Đại Nguyên Soái", icon: "Junxian40.png" },
]);

const ATTRIBUTE_SEQUENCE = Object.freeze([
  "physical_armor",
  "energy_shield",
  "penetration",
  "hit_points",
  "basic_attack_damage",
]);
const ATTRIBUTE_BONUS_PER_ACTIVATION = Object.freeze({
  physical_armor: 1.6,
  energy_shield: 1.6,
  penetration: 1.6,
  hit_points: 24,
  basic_attack_damage: 1.6,
});

function tankLevel(value) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 1;
}

export function calculateMilitaryRankStars(ownedTanks = []) {
  if (!Array.isArray(ownedTanks)) {
    return 0;
  }
  return ownedTanks.reduce((total, tank) => total + tankLevel(tank?.tank_level), 0);
}

export function militaryRankForStars(stars) {
  const safeStars = Math.max(0, Math.floor(Number(stars) || 0));
  let currentIndex = 0;
  let progressStars = safeStars;
  while (currentIndex + 1 < MILITARY_RANKS.length) {
    const required = MILITARY_RANKS[currentIndex + 1].required_stars;
    if (progressStars < required) {
      break;
    }
    progressStars = progressStars - required + 1;
    currentIndex += 1;
  }
  const current = MILITARY_RANKS[currentIndex];
  const next = MILITARY_RANKS[currentIndex + 1] ?? null;
  const progressRequired = next?.required_stars ?? 0;
  const starsPerAttribute = currentIndex + 1;
  const attributeUnlockCount = next
    ? Math.min(4, Math.floor(progressStars / starsPerAttribute))
    : 5;
  const attributeActivationCounts = {};
  const bonuses = {};
  for (let index = 0; index < ATTRIBUTE_SEQUENCE.length; index += 1) {
    const statKey = ATTRIBUTE_SEQUENCE[index];
    const activationCount = currentIndex + (
      index < attributeUnlockCount ? 1 : 0
    );
    attributeActivationCounts[statKey] = activationCount;
    bonuses[statKey] = activationCount * ATTRIBUTE_BONUS_PER_ACTIVATION[statKey];
  }
  const cooldownReductionPercent = Math.floor(current.rank_id / 4) * 0.5;
  const nextMilestoneRank = MILITARY_RANKS.find(
    (rank) => rank.rank_id > current.rank_id && rank.rank_id % 4 === 0,
  ) ?? null;
  return {
    stars: safeStars,
    owned_tank_count: 0,
    current_index: currentIndex,
    current,
    next,
    progress_stars: progressStars,
    progress_required: progressRequired,
    stars_per_attribute: starsPerAttribute,
    attribute_unlock_count: attributeUnlockCount,
    attribute_activation_counts: attributeActivationCounts,
    bonuses,
    cooldown_reduction_percent: cooldownReductionPercent,
    next_cooldown_milestone: nextMilestoneRank,
  };
}

export function buildMilitaryRankSummary(ownedTanks = []) {
  const summary = militaryRankForStars(calculateMilitaryRankStars(ownedTanks));
  summary.owned_tank_count = Array.isArray(ownedTanks) ? ownedTanks.length : 0;
  return summary;
}

export function militaryRankBonusSource(summary = {}) {
  const bonuses = summary?.bonuses ?? {};
  return {
    source_key: "military_rank",
    hit_points: Number(bonuses.hit_points) || 0,
    basic_attack_damage: Number(bonuses.basic_attack_damage) || 0,
    penetration: Number(bonuses.penetration) || 0,
    physical_armor: Number(bonuses.physical_armor) || 0,
    energy_shield: Number(bonuses.energy_shield) || 0,
  };
}

export function applyMilitaryRankCooldowns(skills = [], reductionPercent = 0) {
  if (!Array.isArray(skills)) {
    return [];
  }
  const safeReduction = Math.max(0, Math.min(100, Number(reductionPercent) || 0));
  return skills.map((skill) => {
    const baseCooldown = Math.max(
      0,
      Number(skill?.base_cooldown_ms ?? skill?.cooldown_ms) || 0,
    );
    return {
      ...skill,
      base_cooldown_ms: baseCooldown,
      cooldown_ms: Math.round(baseCooldown * (1 - safeReduction / 100)),
      military_rank_cooldown_reduction_percent: safeReduction,
    };
  });
}
