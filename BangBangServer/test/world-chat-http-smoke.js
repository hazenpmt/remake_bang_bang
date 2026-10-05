import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "../src/db.js";
import { createSessionToken, hashSessionToken } from "../src/security.js";

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = 19_000 + Number.parseInt(randomBytes(2).toString("hex"), 16) % 500;
const baseUrl = `http://127.0.0.1:${port}`;
const token = createSessionToken();
let accountId = null;
let child = null;

async function waitForServer(getServerErrors) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(
    `World chat fixture server did not start in time. ${getServerErrors()}`,
  );
}

try {
  const account = await pool.query(
    `INSERT INTO accounts (username, password_hash)
     VALUES ($1, 'world-chat-smoke-not-a-login-hash')
     RETURNING id`,
    [`chat_${randomBytes(6).toString("hex")}`],
  );
  accountId = account.rows[0].id;
  await pool.query(
    `INSERT INTO player_profiles
       (account_id, display_name, gender, avatar_key)
     VALUES ($1, $2, 'male', 'default_male')`,
    [accountId, `C${randomBytes(4).toString("hex")}`],
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
     VALUES ($1, 'old-server-message', NOW() - INTERVAL '1 day')`,
    [accountId],
  );

  child = spawn(process.execPath, ["src/server.js"], {
    cwd: serverRoot,
    env: {
      ...process.env,
      HOST: "127.0.0.1",
      PORT: String(port),
      BATTLE_RUNTIME_ENABLED: "false",
      WORLD_CHAT_RESET_ON_SERVER_START: "true",
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  let serverErrors = "";
  child.stderr.on("data", (chunk) => { serverErrors += chunk.toString(); });
  await waitForServer(() => serverErrors);

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
  const initialResponse = await fetch(`${baseUrl}/api/chat/messages`, { headers });
  assert.equal(initialResponse.status, 200, serverErrors);
  assert.deepEqual((await initialResponse.json()).messages, []);

  const sendResponse = await fetch(`${baseUrl}/api/chat/messages`, {
    method: "POST",
    headers,
    body: JSON.stringify({ message: "new-server-message" }),
  });
  assert.equal(sendResponse.status, 201, serverErrors);
  const sent = await sendResponse.json();
  assert.equal(sent.message.body, "new-server-message");

  const readResponse = await fetch(`${baseUrl}/api/chat/messages`, { headers });
  assert.equal(readResponse.status, 200, serverErrors);
  const read = await readResponse.json();
  assert.equal(read.messages.length, 1);
  assert.equal(read.messages[0].body, "new-server-message");
  console.log("WORLD_CHAT_HTTP_OK");
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
