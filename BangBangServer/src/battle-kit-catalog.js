const KITS = new Map([
  ["ironman_v1", Object.freeze({
    key: "ironman_v1",
    tankKey: "gangtiexia03",
    passiveShieldRatio: 0.3,
    shieldBreakDamageRatio: 2.36,
    shieldBreakRadius: 300,
    skillRange: 600,
    skillOneDamageRatio: 2.67,
    skillOneRadius: 144,
    skillTwoDamageRatio: 0.75,
    skillTwoRadius: 144,
    beamDamageRatio: 1.25,
    beamHalfWidth: 24,
    beamLifeStealRatio: 0.25,
  })],
]);

export function getBattleKit(kitKey) {
  return KITS.get(String(kitKey ?? "")) ?? null;
}

export function isBattleKitSupported(kitKey) {
  return getBattleKit(kitKey) !== null;
}
