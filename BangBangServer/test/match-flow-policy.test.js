import assert from "node:assert/strict";
import test from "node:test";
import {
  phaseIsComplete,
  summarizeMatchParticipants,
} from "../src/match-flow-policy.js";

function participant(overrides = {}) {
  return {
    confirmed: false,
    deployed: false,
    load_progress: 0,
    load_ready: false,
    ...overrides,
  };
}

test("TEST match waits for one real ally and five bots, not four missing ally slots", () => {
  const participants = [
    participant({ confirmed: true }),
    ...Array.from({ length: 5 }, () => participant({ confirmed: true })),
  ];
  const summary = summarizeMatchParticipants(participants);

  assert.equal(summary.requiredCount, 6);
  assert.equal(summary.confirmedCount, 6);
  assert.equal(phaseIsComplete(participants, "confirmed"), true);
});

test("normal 5v5 match requires all ten participants", () => {
  const participants = Array.from(
    { length: 10 },
    (_, index) => participant({ confirmed: index < 9 }),
  );

  assert.equal(phaseIsComplete(participants, "confirmed"), false);
  participants[9].confirmed = true;
  assert.equal(phaseIsComplete(participants, "confirmed"), true);
});

test("loading only completes when every required participant reports ready at 100", () => {
  const participants = [
    participant({ deployed: true, load_progress: 100, load_ready: true }),
    participant({ deployed: true, load_progress: 90, load_ready: false }),
  ];

  assert.equal(phaseIsComplete(participants, "deployed"), true);
  assert.equal(phaseIsComplete(participants, "loaded"), false);
  participants[1].load_progress = 100;
  participants[1].load_ready = true;
  assert.equal(phaseIsComplete(participants, "loaded"), true);
});
