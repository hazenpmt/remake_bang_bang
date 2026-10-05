import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "../src/db.js";
import { createSessionToken, hashSessionToken } from "../src/security.js";

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = 18_000 + Number.parseInt(randomBytes(2).toString("hex"), 16) % 1000;
const baseUrl = `http://127.0.0.1:${port}`;
const token = createSessionToken();
let accountId = null;
let child = null;

async function waitForServer() {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) {
        return;
      }
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Server smoke không khởi động kịp.");
}

try {
  const account = await pool.query(
    `INSERT INTO accounts (username, password_hash)
     VALUES ($1, 'smoke-test-not-a-login-hash')
     RETURNING id`,
    [`api_${randomBytes(6).toString("hex")}`],
  );
  accountId = account.rows[0].id;
  await pool.query(
    `INSERT INTO player_profiles
       (account_id, display_name, gender, avatar_key)
     VALUES ($1, $2, 'male', 'default_male')`,
    [accountId, `S${randomBytes(4).toString("hex")}`],
  );
  await pool.query(
    `INSERT INTO player_currencies (account_id, xu, locked_xu, silver)
     VALUES ($1, 0, 0, 0)`,
    [accountId],
  );
  const session = await pool.query(
    `INSERT INTO sessions (account_id, token_hash, expires_at)
     VALUES ($1, $2, NOW() + INTERVAL '10 minutes')
     RETURNING id`,
    [accountId, hashSessionToken(token)],
  );
  await pool.query(
    `INSERT INTO online_presence
       (account_id, session_id, lease_expires_at)
     VALUES ($1, $2, NOW() + INTERVAL '10 minutes')`,
    [accountId, session.rows[0].id],
  );

  child = spawn(process.execPath, ["src/server.js"], {
    cwd: serverRoot,
    env: {
      ...process.env,
      HOST: "127.0.0.1",
      PORT: String(port),
      BATTLE_RUNTIME_ENABLED: "false",
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  let serverErrors = "";
  child.stderr.on("data", (chunk) => { serverErrors += chunk.toString(); });
  await waitForServer();

  const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  const catalogResponse = await fetch(`${baseUrl}/api/shop/catalog`, { headers });
  assert.equal(catalogResponse.status, 200, serverErrors);
  const catalogPayload = await catalogResponse.json();
  assert.equal(catalogPayload.ok, true);
  assert.equal(catalogPayload.catalog.items.length, 36);
  assert.equal(catalogPayload.catalog.offers.length, 36);
  assert.equal(catalogPayload.catalog.revision, 1);

  const missingKeyResponse = await fetch(`${baseUrl}/api/shop/purchases`, {
    method: "POST",
    headers,
    body: JSON.stringify({ offer_id: "offer_green_yoyo", quantity: 1, price: 0 }),
  });
  assert.equal(missingKeyResponse.status, 400);
  assert.equal((await missingKeyResponse.json()).error.code, "IDEMPOTENCY_KEY_REQUIRED");

  const noMoneyResponse = await fetch(`${baseUrl}/api/shop/purchases`, {
    method: "POST",
    headers: { ...headers, "Idempotency-Key": randomBytes(24).toString("hex") },
    body: JSON.stringify({
      offer_id: "offer_green_yoyo",
      quantity: 1,
      price: 0,
      currency: "free",
    }),
  });
  assert.equal(noMoneyResponse.status, 409);
  assert.equal((await noMoneyResponse.json()).error.code, "INSUFFICIENT_FUNDS");
  const audit = await pool.query(
    `SELECT
       (SELECT COUNT(*) FROM purchase_orders WHERE account_id = $1)::int AS orders,
       (SELECT COUNT(*) FROM economy_ledger WHERE account_id = $1)::int AS ledger`,
    [accountId],
  );
  assert.deepEqual(audit.rows[0], { orders: 0, ledger: 0 });
  console.log("SHOP_API_HTTP_OK");
} finally {
  if (child && child.exitCode == null) {
    child.kill();
    await new Promise((resolve) => child.once("exit", resolve));
  }
  if (accountId != null) {
    await pool.query("DELETE FROM accounts WHERE id = $1", [accountId]).catch(() => {});
  }
  await pool.end();
}
