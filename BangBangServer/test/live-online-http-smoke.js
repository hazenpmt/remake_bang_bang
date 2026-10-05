import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { pool } from "../src/db.js";
import { createSessionToken, hashSessionToken } from "../src/security.js";

const baseUrl = (process.env.LIVE_API_BASE_URL ?? "http://127.0.0.1:8080").replace(/\/+$/, "");
const token = createSessionToken();
let accountId = null;

try {
  const account = await pool.query(
    `INSERT INTO accounts (username, password_hash)
     VALUES ($1, 'live-online-smoke-not-a-login-hash')
     RETURNING id`,
    [`live_${randomBytes(6).toString("hex")}`],
  );
  accountId = account.rows[0].id;
  await pool.query(
    `INSERT INTO player_profiles
       (account_id, display_name, gender, avatar_key)
     VALUES ($1, $2, 'male', 'default_male')`,
    [accountId, `L${randomBytes(4).toString("hex")}`],
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
  await pool.query(
    `INSERT INTO chat_messages (sender_account_id, body, created_at)
     VALUES ($1, 'live-old-server-message', NOW() - INTERVAL '1 day')`,
    [accountId],
  );

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
  const initialResponse = await fetch(`${baseUrl}/api/chat/messages`, { headers });
  assert.equal(initialResponse.status, 200);
  const initial = await initialResponse.json();
  assert.equal(
    initial.messages.some((message) => message.body === "live-old-server-message"),
    false,
  );

  const sendResponse = await fetch(`${baseUrl}/api/chat/messages`, {
    method: "POST",
    headers,
    body: JSON.stringify({ message: "live-new-server-message" }),
  });
  assert.equal(sendResponse.status, 201);
  const sent = await sendResponse.json();
  assert.equal(sent.message.body, "live-new-server-message");

  const readResponse = await fetch(`${baseUrl}/api/chat/messages`, { headers });
  assert.equal(readResponse.status, 200);
  const read = await readResponse.json();
  assert.equal(
    read.messages.some((message) => message.body === "live-new-server-message"),
    true,
  );

  const roomsResponse = await fetch(`${baseUrl}/api/rooms?tab=test`, { headers });
  assert.equal(roomsResponse.status, 200);
  const rooms = (await roomsResponse.json()).rooms;
  assert.ok(Array.isArray(rooms));
  for (const room of rooms) {
    assert.equal(typeof room.map_name, "string");
    assert.notEqual(room.map_name.trim(), "");
    assert.equal(typeof room.map_thumbnail_asset_path, "string");
  }
  console.log("LIVE_ONLINE_HTTP_OK");
} finally {
  if (accountId != null) {
    await pool.query("DELETE FROM accounts WHERE id = $1", [accountId]).catch(() => {});
  }
  await pool.end();
}
