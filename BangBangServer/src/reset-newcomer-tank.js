import { pool, withTransaction } from "./db.js";
import { normalizeUsername } from "./validation.js";

const username = normalizeUsername(process.argv[2]);
const confirmation = String(process.argv[3] ?? "");

if (!username || confirmation !== "CONFIRM") {
  console.error(
    "Usage: npm run reset-newcomer-tank -- <username> CONFIRM",
  );
  process.exitCode = 2;
} else {
  try {
    const result = await withTransaction(async (client) => {
      const accountResult = await client.query(
        `SELECT id, username
           FROM accounts
          WHERE LOWER(username) = $1
          FOR UPDATE`,
        [username],
      );
      if (accountResult.rowCount !== 1) {
        return null;
      }

      const account = accountResult.rows[0];
      const tankResult = await client.query(
        `SELECT id
           FROM tanks
          WHERE tank_key = 'gangtiexia03'`,
      );
      if (tankResult.rowCount !== 1) {
        throw new Error("Iron Man is missing from the tank catalog.");
      }
      const tankId = tankResult.rows[0].id;

      await client.query(
        `DELETE FROM player_tank_skins owned_skin
          USING tank_skins skin
          WHERE owned_skin.account_id = $1
            AND owned_skin.tank_skin_id = skin.id
            AND skin.tank_id = $2`,
        [account.id, tankId],
      );
      await client.query(
        `DELETE FROM player_tanks
          WHERE account_id = $1
            AND tank_id = $2`,
        [account.id, tankId],
      );
      await client.query(
        `INSERT INTO player_rewards (
             account_id,
             reward_key,
             status,
             offered_at,
             claimed_at
         )
         VALUES ($1, 'newcomer_iron_man', 'pending', NOW(), NULL)
         ON CONFLICT (account_id, reward_key) DO UPDATE
         SET status = 'pending',
             offered_at = NOW(),
             claimed_at = NULL`,
        [account.id],
      );

      return account;
    });

    if (result === null) {
      console.error(`Account not found: ${username}`);
      process.exitCode = 1;
    } else {
      console.log(
        `Reset newcomer Iron Man reward for account: ${result.username}`,
      );
    }
  } finally {
    await pool.end().catch(() => {});
  }
}
