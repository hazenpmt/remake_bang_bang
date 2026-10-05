import test from "node:test";
import assert from "node:assert/strict";
import {
  applyCharacterExperience,
  EXPERIENCE_MAX_BY_LEVEL,
  experienceMaxForLevel,
} from "../src/character-levels.js";

test("character EXP requirements match the original level table", () => {
  assert.equal(EXPERIENCE_MAX_BY_LEVEL.length, 41);
  assert.equal(experienceMaxForLevel(1), 350);
  assert.equal(experienceMaxForLevel(15), 13000);
  assert.equal(experienceMaxForLevel(20), 42000);
  assert.equal(experienceMaxForLevel(40), 0);
});

test("character EXP lookup clamps invalid levels", () => {
  assert.equal(experienceMaxForLevel(-5), 150);
  assert.equal(experienceMaxForLevel(999), 0);
  assert.equal(experienceMaxForLevel("15"), 13000);
});

test("authoritative character EXP carries across levels and stops at max", () => {
  assert.deepEqual(applyCharacterExperience(1, 340, 20), {
    level: 2,
    experience: 10,
    levelsGained: 1,
  });
  assert.deepEqual(applyCharacterExperience(1, 340, 600), {
    level: 3,
    experience: 40,
    levelsGained: 2,
  });
  assert.deepEqual(applyCharacterExperience(40, 123, 999), {
    level: 40,
    experience: 0,
    levelsGained: 0,
  });
});
