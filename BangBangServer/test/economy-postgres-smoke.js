import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { pool } from "../src/db.js";
import {
  EconomyError,
  purchaseOffer,
  validatePurchaseRequest,
} from "../src/economy.js";

const client = await pool.connect();
try {
  await client.query("BEGIN");
  const username = `econ_${randomBytes(6).toString("hex")}`;
  const account = await client.query(
    `INSERT INTO accounts (username, password_hash)
     VALUES ($1, 'smoke-test-not-a-login-hash')
     RETURNING id`,
    [username],
  );
  const accountId = account.rows[0].id;
  await client.query(
    `INSERT INTO player_profiles
       (account_id, display_name, gender, avatar_key)
     VALUES ($1, $2, 'male', 'default_male')`,
    [accountId, `E${randomBytes(4).toString("hex")}`],
  );
  await client.query(
    `INSERT INTO player_currencies (account_id, xu, locked_xu, silver)
     VALUES ($1, 100, 1000, 10000)`,
    [accountId],
  );

  const key = randomBytes(24).toString("hex");
  const input = validatePurchaseRequest(
    { offer_id: "offer_chip_1", quantity: 1, price: 0 },
    key,
  );
  const first = await purchaseOffer(client, accountId, input);
  assert.equal(first.total_price, 100);
  assert.equal(first.balances.silver, 9900);
  assert.equal(first.grant.balance_after, 1);
  assert.equal(first.idempotent_replay, false);

  const replay = await purchaseOffer(client, accountId, input);
  assert.equal(replay.purchase_id, first.purchase_id);
  assert.equal(replay.idempotent_replay, true);

  await assert.rejects(
    purchaseOffer(client, accountId, { ...input, quantity: 2 }),
    (error) => error instanceof EconomyError && error.code === "IDEMPOTENCY_CONFLICT",
  );
  const state = await client.query(
    `SELECT currency.silver, stack.quantity,
            (SELECT COUNT(*) FROM purchase_orders
              WHERE account_id = $1) AS order_count,
            (SELECT COUNT(*) FROM economy_ledger
              WHERE account_id = $1) AS ledger_count
       FROM player_currencies currency
       JOIN inventory_stacks stack
         ON stack.account_id = currency.account_id AND stack.item_id = 'chip_1'
      WHERE currency.account_id = $1`,
    [accountId],
  );
  assert.equal(Number(state.rows[0].silver), 9900);
  assert.equal(Number(state.rows[0].quantity), 1);
  assert.equal(Number(state.rows[0].order_count), 1);
  assert.equal(Number(state.rows[0].ledger_count), 2);

  const noMoneyKey = randomBytes(24).toString("hex");
  await assert.rejects(
    purchaseOffer(client, accountId, validatePurchaseRequest(
      { offer_id: "offer_green_yoyo", quantity: 1 },
      noMoneyKey,
    )),
    (error) => error instanceof EconomyError && error.code === "INSUFFICIENT_FUNDS",
  );
  const failedOrder = await client.query(
    "SELECT 1 FROM purchase_orders WHERE account_id = $1 AND idempotency_key = $2",
    [accountId, noMoneyKey],
  );
  assert.equal(failedOrder.rowCount, 0);

  await client.query("SAVEPOINT ledger_immutability");
  await assert.rejects(
    client.query(
      "UPDATE economy_ledger SET delta = 1 WHERE account_id = $1",
      [accountId],
    ),
    /append-only/,
  );
  await client.query("ROLLBACK TO SAVEPOINT ledger_immutability");
  console.log("ECONOMY_POSTGRES_OK");
} finally {
  await client.query("ROLLBACK").catch(() => {});
  client.release();
  await pool.end();
}
