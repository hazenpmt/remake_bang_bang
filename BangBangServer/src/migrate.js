import { pool } from "./db.js";
import { runMigrations } from "./migrations.js";

try {
  await runMigrations(pool);
  console.log("Database migration completed.");
} finally {
  await pool.end();
}
