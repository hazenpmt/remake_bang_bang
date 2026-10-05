import { pool, withTransaction } from "./db.js";
import { hashPassword } from "./security.js";
import { normalizeUsername } from "./validation.js";

const username = normalizeUsername(process.env.ADMIN_USERNAME);
const password = String(process.env.ADMIN_PASSWORD ?? "");

if (!/^[a-z0-9_]{3,24}$/.test(username)) {
  console.error("ADMIN_USERNAME phải dài 3–24 ký tự và chỉ gồm chữ thường, số hoặc dấu gạch dưới.");
  process.exitCode = 2;
} else if (password.length < 6 || password.length > 15) {
  console.error("ADMIN_PASSWORD phải dài từ 6 đến 15 ký tự.");
  process.exitCode = 2;
} else {
  try {
    const passwordHash = await hashPassword(password);
    const result = await withTransaction(async (client) => {
      const existing = await client.query(
        "SELECT id FROM accounts WHERE LOWER(username) = $1 FOR UPDATE",
        [username],
      );

      let account;
      if (existing.rowCount === 1) {
        const updated = await client.query(
          `UPDATE accounts
              SET password_hash = $2,
                  role = 'admin',
                  status = 'active'
            WHERE id = $1
          RETURNING id, username, role, status`,
          [existing.rows[0].id, passwordHash],
        );
        account = updated.rows[0];
        await client.query("DELETE FROM sessions WHERE account_id = $1", [account.id]);
      } else {
        const inserted = await client.query(
          `INSERT INTO accounts (username, password_hash, role, status)
           VALUES ($1, $2, 'admin', 'active')
           RETURNING id, username, role, status`,
          [username, passwordHash],
        );
        account = inserted.rows[0];
      }

      await client.query(
        `INSERT INTO admin_audit_log
           (target_account_id, action, details)
         VALUES ($1, 'admin_provisioned_from_console', $2::jsonb)`,
        [account.id, JSON.stringify({ username: account.username })],
      );
      return account;
    });

    console.log(
      `Admin ready: ${result.username} (${result.role}, ${result.status}).`,
    );
  } finally {
    await pool.end().catch(() => {});
  }
}
