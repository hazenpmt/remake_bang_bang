import assert from "node:assert/strict";

import { pool } from "../src/db.js";

const client = await pool.connect();
try {
  await client.query("BEGIN");
  const inserted = await client.query(
    `INSERT INTO security_events
       (event_type, severity, source, node_id, details)
     VALUES ('smoke.test', 'high', 'system', 'smoke-node', '{"safe":true}')
     RETURNING id`,
  );
  assert.equal(inserted.rowCount, 1);
  await client.query("SAVEPOINT security_append_only");
  await assert.rejects(
    client.query(
      "UPDATE security_events SET severity = 'low' WHERE id = $1",
      [inserted.rows[0].id],
    ),
    /append-only/,
  );
  await client.query("ROLLBACK TO SAVEPOINT security_append_only");
  console.log("SECURITY_POSTGRES_OK");
} finally {
  await client.query("ROLLBACK").catch(() => {});
  client.release();
  await pool.end();
}
