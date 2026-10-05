import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { mkdtemp, open, readFile, rm } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import path from "node:path";

import pg from "pg";

import { postgresCliConnection, resolvePostgresTool, runPostgresTool } from "./postgres-tools.js";

const { Client } = pg;
const archivePath = path.resolve(process.cwd(), process.argv[2] ?? "");
if (!process.argv[2] || !archivePath.endsWith(".dump")) {
  throw new Error("Usage: npm run verify-backup -- <path-to.dump>");
}

function reservePort() {
  return new Promise((resolve, reject) => {
    const socket = createServer();
    socket.once("error", reject);
    socket.listen(0, "127.0.0.1", () => {
      const port = socket.address().port;
      socket.close((error) => (error ? reject(error) : resolve(port)));
    });
  });
}

async function waitForPostgres(connectionString, child) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (child.exitCode != null) {
      throw new Error(`Temporary PostgreSQL exited with code ${child.exitCode}.`);
    }
    const probe = new Client({ connectionString, connectionTimeoutMillis: 250 });
    try {
      await probe.connect();
      await probe.query("SELECT 1");
      await probe.end();
      return;
    } catch {
      await probe.end().catch(() => {});
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  throw new Error("Temporary PostgreSQL did not become ready.");
}

const manifestPath = archivePath.replace(/\.dump$/i, ".manifest.json");
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const hash = createHash("sha256");
const archive = await open(archivePath, "r");
try {
  for await (const chunk of archive.createReadStream({ autoClose: false })) {
    hash.update(chunk);
  }
} finally {
  await archive.close();
}
if (hash.digest("hex") !== manifest.sha256) {
  throw new Error("Backup checksum mismatch.");
}

const tempRoot = path.resolve(tmpdir());
const clusterPrefix = path.join(tempRoot, "bangbang-restore-check-");
const clusterPath = await mkdtemp(clusterPrefix);
const resolvedCluster = path.resolve(clusterPath);
if (!resolvedCluster.startsWith(clusterPrefix)) {
  throw new Error("Generated restore cluster path is unsafe.");
}
const port = await reservePort();
const initdb = await resolvePostgresTool("initdb");
const pgCtl = await resolvePostgresTool("pg_ctl");
const postgres = await resolvePostgresTool("postgres");
let started = false;
let restore = null;

try {
  await runPostgresTool(initdb, [
    "--pgdata", clusterPath,
    "--username", "postgres",
    "--auth", "trust",
    "--encoding", "UTF8",
    "--no-locale",
  ]);
  const postgresProcess = spawn(postgres, [
    "-D", clusterPath,
    "-p", String(port),
    "-h", "127.0.0.1",
  ], {
    detached: true,
    stdio: "ignore",
    windowsHide: true,
  });
  postgresProcess.unref();
  const restoreUrl = `postgresql://postgres@127.0.0.1:${port}/postgres`;
  await waitForPostgres(restoreUrl, postgresProcess);
  started = true;
  const connection = postgresCliConnection(restoreUrl);
  await runPostgresTool("pg_restore", [
    ...connection.args,
    "--no-owner",
    "--no-privileges",
    "--exit-on-error",
    archivePath,
  ], { env: connection.env });
  restore = new Client({ connectionString: restoreUrl });
  await restore.connect();
  const result = await restore.query(
    `SELECT
       (SELECT COUNT(*)::bigint FROM accounts)::text AS accounts,
       (SELECT COUNT(*)::bigint FROM economy_ledger)::text AS economy_ledger,
       (SELECT COUNT(*)::bigint FROM purchase_orders)::text AS purchase_orders,
       (SELECT COUNT(*)::bigint FROM game_matches)::text AS game_matches,
       (SELECT COUNT(*)::bigint FROM game_match_battle_rewards)::text AS battle_rewards,
       (SELECT COUNT(*)::bigint FROM security_events)::text AS security_events,
       (SELECT COUNT(*)::bigint FROM schema_migrations)::text AS schema_migrations,
       EXISTS (
         SELECT 1 FROM pg_trigger
          WHERE tgname = 'economy_ledger_append_only' AND tgenabled <> 'D'
       ) AS economy_append_only,
       EXISTS (
         SELECT 1 FROM pg_trigger
          WHERE tgname = 'game_match_battle_rewards_append_only' AND tgenabled <> 'D'
       ) AS rewards_append_only,
       EXISTS (
         SELECT 1 FROM pg_trigger
          WHERE tgname = 'security_events_append_only' AND tgenabled <> 'D'
       ) AS security_append_only`,
  );
  const row = result.rows[0];
  for (const [key, expected] of Object.entries(manifest.counts)) {
    if (row[key] !== expected) {
      throw new Error(`Restored count mismatch for ${key}: ${row[key]} != ${expected}`);
    }
  }
  if (!row.economy_append_only || !row.rewards_append_only || !row.security_append_only) {
    throw new Error("Restored append-only audit triggers are incomplete.");
  }
  console.log(`DATABASE_RESTORE_DRILL_OK ${path.basename(archivePath)}`);
} finally {
  await restore?.end().catch(() => {});
  if (started) {
    await runPostgresTool(pgCtl, [
      "--pgdata", clusterPath,
      "--mode", "fast",
      "--wait",
      "stop",
    ]).catch(() => {});
  }
  await rm(clusterPath, { recursive: true, force: true });
}
