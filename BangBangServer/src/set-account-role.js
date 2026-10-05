import { pool, withTransaction } from "./db.js";
import { normalizeUsername } from "./validation.js";

const username = normalizeUsername(process.argv[2]);
const role = String(process.argv[3] ?? "").toLowerCase();

if (!username || !["player", "admin"].includes(role)) {
  console.error("Usage: npm run set-role -- <username> <player|admin>");
  process.exitCode = 2;
} else {
  try {
    const result = await withTransaction(async (client) => {
      const updated = await client.query(
        `UPDATE accounts
            SET role = $2
          WHERE LOWER(username) = $1
          RETURNING id, username, role`,
        [username, role],
      );
      if (updated.rowCount !== 1) {
        return null;
      }

      const account = updated.rows[0];
      await client.query("DELETE FROM sessions WHERE account_id = $1", [account.id]);
      await client.query(
        `INSERT INTO admin_audit_log
           (target_account_id, action, details)
         VALUES ($1, 'role_changed_from_console', $2::jsonb)`,
        [account.id, JSON.stringify({ role })],
      );
      return account;
    });

    if (!result) {
      console.error(`Account not found: ${username}`);
      process.exitCode = 1;
    } else {
      console.log(
        `Updated ${result.username} to role ${result.role}. Existing sessions were revoked.`,
      );
    }
  } finally {
    await pool.end().catch(() => {});
  }
}
