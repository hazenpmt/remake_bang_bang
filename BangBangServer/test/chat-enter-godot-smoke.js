import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import { pool } from "../src/db.js";
import { createSessionToken, hashSessionToken } from "../src/security.js";

const godot = process.env.GODOT_BIN
  ?? "D:\\Godot_v4.7.1-stable_win64.exe\\Godot_v4.7.1-stable_win64_console.exe";
const project = new URL("../../BangBangRemake", import.meta.url).pathname
  .replace(/^\/(?:([A-Za-z]):)/, "$1:");
const baseUrl = (process.env.LIVE_API_BASE_URL ?? "http://127.0.0.1:8080")
  .replace(/\/+$/, "");
const token = createSessionToken();
const body = `enter_${randomBytes(6).toString("hex")}`;
let accountId = null;

try {
  const account = await pool.query(
    `INSERT INTO accounts (username, password_hash)
     VALUES ($1, 'chat-enter-smoke-not-a-login-hash')
     RETURNING id`,
    [`enter_${randomBytes(6).toString("hex")}`],
  );
  accountId = account.rows[0].id;
  await pool.query(
    `INSERT INTO player_profiles
       (account_id, display_name, gender, avatar_key)
     VALUES ($1, 'EnterBot', 'male', 'default_male')`,
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

  const child = spawn(
    godot,
    ["--headless", "--path", project, "--script", "res://tests/chat_enter_live_smoke.gd"],
    {
      env: {
        ...process.env,
        CHAT_SMOKE_TOKEN: token,
        CHAT_SMOKE_BODY: body,
        CHAT_SMOKE_API_BASE: `${baseUrl}/api`,
      },
      windowsHide: true,
    },
  );
  let output = "";
  child.stdout.on("data", (chunk) => { output += chunk.toString(); });
  child.stderr.on("data", (chunk) => { output += chunk.toString(); });
  const exitCode = await new Promise((resolve) => child.once("exit", resolve));
  assert.equal(exitCode, 0, output);
  assert.match(output, /CHAT_ENTER_LIVE_OK/, output);
  console.log("CHAT_ENTER_GODOT_OK");
} finally {
  if (accountId != null) {
    await pool.query("DELETE FROM accounts WHERE id = $1", [accountId]).catch(() => {});
  }
  await pool.end();
}
