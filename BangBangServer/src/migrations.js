import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const sqlDirectory = new URL("../sql/", import.meta.url);

export async function runMigrations(client) {
  await client.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       name TEXT PRIMARY KEY,
       applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
     )`,
  );

  const files = (await readdir(fileURLToPath(sqlDirectory)))
    .filter((name) => /^\d+.*\.sql$/i.test(name))
    .sort();

  for (const name of files) {
    const existing = await client.query(
      "SELECT 1 FROM schema_migrations WHERE name = $1",
      [name],
    );
    if (existing.rowCount > 0) {
      continue;
    }

    const sql = await readFile(new URL(`../sql/${name}`, import.meta.url), "utf8");
    await client.query(sql);
    await client.query("INSERT INTO schema_migrations(name) VALUES ($1)", [name]);
    console.log(`Applied migration: ${name}`);
  }
}
