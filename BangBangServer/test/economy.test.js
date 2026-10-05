import assert from "node:assert/strict";
import test from "node:test";
import {
  EconomyError,
  purchaseRequestHash,
  validatePurchaseRequest,
} from "../src/economy.js";

test("purchase request accepts only offer, quantity and idempotency key", () => {
  const input = validatePurchaseRequest(
    {
      offer_id: "offer_chip_1",
      quantity: 2,
      price: 0,
      currency: "silver",
      item_id: "admin_item",
    },
    "1234567890abcdef1234567890abcdef",
  );
  assert.deepEqual(input, {
    offerId: "offer_chip_1",
    quantity: 2,
    idempotencyKey: "1234567890abcdef1234567890abcdef",
  });
  assert.equal("price" in input, false);
  assert.equal("currency" in input, false);
});

test("purchase rejects missing idempotency and invalid quantity", () => {
  assert.throws(
    () => validatePurchaseRequest({ offer_id: "offer_chip_1", quantity: 1 }, ""),
    (error) => error instanceof EconomyError && error.code === "IDEMPOTENCY_KEY_REQUIRED",
  );
  assert.throws(
    () => validatePurchaseRequest(
      { offer_id: "offer_chip_1", quantity: 1000 },
      "1234567890abcdef1234567890abcdef",
    ),
    (error) => error instanceof EconomyError && error.code === "INVALID_QUANTITY",
  );
});

test("idempotency request hash binds the key to exact purchase parameters", () => {
  assert.equal(
    purchaseRequestHash("offer_chip_1", 1),
    purchaseRequestHash("offer_chip_1", 1),
  );
  assert.notEqual(
    purchaseRequestHash("offer_chip_1", 1),
    purchaseRequestHash("offer_chip_1", 2),
  );
});
