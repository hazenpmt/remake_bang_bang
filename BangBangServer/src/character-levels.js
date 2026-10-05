// Original character EXP requirements from rez/zh_CN/xml/CharLevelTemplate_table.xml.
export const EXPERIENCE_MAX_BY_LEVEL = Object.freeze([
  150,
  350,
  550,
  800,
  1000,
  1250,
  1600,
  2000,
  2500,
  3300,
  4500,
  5800,
  6800,
  8300,
  10000,
  13000,
  15000,
  19000,
  22000,
  27000,
  42000,
  50000,
  60000,
  73000,
  87000,
  156000,
  191000,
  227000,
  270000,
  330000,
  363000,
  399300,
  439200,
  483200,
  531500,
  956700,
  1148000,
  1377600,
  1653200,
  1983800,
  -1,
]);

export function experienceMaxForLevel(level) {
  const numericLevel = Number.isFinite(Number(level))
    ? Math.trunc(Number(level))
    : 0;
  const safeLevel = Math.min(
    EXPERIENCE_MAX_BY_LEVEL.length - 1,
    Math.max(0, numericLevel),
  );
  return Math.max(0, EXPERIENCE_MAX_BY_LEVEL[safeLevel]);
}

export function applyCharacterExperience(levelValue, experienceValue, rewardValue) {
  let level = Math.max(1, Math.min(
    EXPERIENCE_MAX_BY_LEVEL.length - 1,
    Math.trunc(Number(levelValue) || 1),
  ));
  let experience = Math.max(0, Math.trunc(Number(experienceValue) || 0));
  const reward = Math.max(0, Math.trunc(Number(rewardValue) || 0));
  const levelBefore = level;
  experience += reward;
  while (level < EXPERIENCE_MAX_BY_LEVEL.length - 1) {
    const required = experienceMaxForLevel(level);
    if (required <= 0 || experience < required) {
      break;
    }
    experience -= required;
    level += 1;
  }
  if (level >= EXPERIENCE_MAX_BY_LEVEL.length - 1) {
    experience = 0;
  }
  return {
    level,
    experience,
    levelsGained: level - levelBefore,
  };
}
