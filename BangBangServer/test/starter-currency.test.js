import assert from "node:assert/strict";
import test from "node:test";
import { STARTER_CURRENCY_BALANCE } from "../src/starter-currency.js";

test("new characters receive the one-time starter currency balance", () => {
  assert.deepEqual(STARTER_CURRENCY_BALANCE, {
    xu: 100,
    lockedXu: 1_000,
    silver: 10_000,
  });
  assert.equal(Object.isFrozen(STARTER_CURRENCY_BALANCE), true);
});
