import { createHash } from "node:crypto";
import { mkdir, open, rename, writeFile } from "node:fs/promises";
import path from "node:path";

import pg from "pg";

import { config } from "./config.js";
import { postgresCliConnection, runPostgresTool } from "./postgres-tools.js";

const { Pool } = pg;
const requestedDirectory = process.argv[2] || "backups";
const outputDirectory = path.resolve(process.cwd(), requestedDirectory);
await mkdir(outputDirectory, { recursive: true });

const timestamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
const baseName = `bangbang-${timestamp}`;
const temporaryPath = path.join(outputDirectory, `${baseName}.dump.partial`);
const backupPath = path.join(outputDirectory, `${baseName}.dump`);
const manifestPath = path.join(outputDirectory, `${baseName}.manifest.json`);
const connection = postgresCliConnection(config.databaseUrl);
const pool = new Pool({ connectionString: config.databaseUrl, max: 2 });

try {
  const counts = await pool.query(
    `SELECT
       (SELECT COUNT(*)::bigint FROM accounts)::text AS accounts,
       (SELECT COUNT(*)::bigint FROM economy_ledger)::text AS economy_ledger,
       (SELECT COUNT(*)::bigint FROM purchase_orders)::text AS purchase_orders,
       (SELECT COUNT(*)::bigint FROM game_matches)::text AS game_matches,
       (SELECT COUNT(*)::bigint FROM game_match_battle_rewards)::text AS battle_rewards,
       (SELECT COUNT(*)::bigint FROM security_events)::text AS security_events,
       (SELECT COUNT(*)::bigint FROM schema_migrations)::text AS schema_migrations`,
  );
  await runPostgresTool("pg_dump", [
    ...connection.args,
    "--format=custom",
    "--compress=9",
    "--no-owner",
    "--no-privileges",
    "--file", temporaryPath,
  ], { env: connection.env });
  await rename(temporaryPath, backupPath);
  const hash = createHash("sha256");
  const handle = await open(backupPath, "r");
  try {
    for await (const chunk of handle.createReadStream({ autoClose: false })) {
      hash.update(chunk);
    }
  } finally {
    await handle.close();
  }
  const manifest = {
    format_version: 1,
    created_at: new Date().toISOString(),
    archive: path.basename(backupPath),
    sha256: hash.digest("hex"),
    counts: counts.rows[0],
  };
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  console.log(`DATABASE_BACKUP_OK ${backupPath}`);
} finally {
  await pool.end();
}
