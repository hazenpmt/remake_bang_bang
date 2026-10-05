import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { access, rm } from "node:fs/promises";
import path from "node:path";
import { pool } from "../src/db.js";
import { config } from "../src/config.js";
import { readPublishedManifest, saveImageAsset } from "../src/content-delivery.js";
import { loadPublishedCatalog } from "../src/shop-catalog.js";
import {
  publishShopDraft,
  readShopEditorState,
  saveShopDraft,
} from "../src/shop-publishing.js";

// 1x1 transparent PNG. It is used as test input only and never enters game assets.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
  "base64",
);

const client = await pool.connect();
let storedPath = "";
let fileExistedBefore = false;
try {
  const admin = await client.query(
    "SELECT id FROM accounts WHERE role = 'admin' ORDER BY id LIMIT 1",
  );
  assert.equal(admin.rowCount, 1, "Local smoke requires an admin account");
  await client.query("BEGIN");

  const live = await loadPublishedCatalog(client);
  assert.ok(live.shelves.length > 0, "Shop requires at least one shelf");
  const testItemId = "content_smoke_item";
  const testAssetId = "content_smoke_image";
  const catalog = structuredClone(live);
  catalog.items = catalog.items.filter((item) => item.item_id !== testItemId);
  catalog.offers = catalog.offers.filter((offer) => offer.item_id !== testItemId);
  catalog.items.push({
    item_id: testItemId,
    item_type: "material",
    name: "Content smoke",
    description: "transaction rollback fixture",
    image: `content://${testAssetId}`,
    fallback_image: "res://shop_content/fallback.png",
    grant: { kind: "inventory_stack" },
    enabled: true,
  });
  catalog.offers.push({
    offer_id: "content_smoke_offer",
    item_id: testItemId,
    shelf_ids: [live.shelves[0].shelf_id],
    currency: "silver",
    price: 1,
    badges: ["new"],
    max_quantity_per_order: 1,
    giftable: false,
    preview_enabled: false,
    sort_priority: -100000,
    required_level: 1,
    required_vip: false,
    enabled: true,
  });

  const expectedHash = createHash("sha256").update(PNG).digest("hex");
  storedPath = path.resolve(config.contentStorageRoot, `images/${expectedHash}.png`);
  try {
    await access(storedPath);
    fileExistedBefore = true;
  } catch {
    fileExistedBefore = false;
  }
  const asset = await saveImageAsset({
    assetId: testAssetId,
    originalFilename: "smoke.png",
    body: PNG,
    uploadedBy: admin.rows[0].id,
    query: (sql, parameters) => client.query(sql, parameters),
  });
  assert.equal(path.resolve(config.contentStorageRoot, asset.storage_key), storedPath);

  await saveShopDraft(client, admin.rows[0].id, catalog);
  const published = await publishShopDraft(client, admin.rows[0].id);
  assert.equal(published.release.asset_count, 1);
  const manifest = await readPublishedManifest((sql, parameters) =>
    client.query(sql, parameters)
  );
  assert.equal(manifest.catalog_revision, published.release.catalog_revision);
  assert.equal(manifest.assets[0].asset_id, testAssetId);
  assert.equal(manifest.assets[0].sha256, asset.sha256);
  const editor = await readShopEditorState(client);
  assert.equal(editor.revision, published.release.catalog_revision);
  assert.ok(editor.releases.some((release) => release.id === published.release.id));

  await client.query("ROLLBACK");
  console.log("CONTENT_PUBLISHING_POSTGRES_OK");
} catch (error) {
  try { await client.query("ROLLBACK"); } catch {}
  throw error;
} finally {
  client.release();
  await pool.end();
  if (storedPath && !fileExistedBefore) {
    const root = path.resolve(config.contentStorageRoot) + path.sep;
    if (storedPath.startsWith(root)) await rm(storedPath, { force: true });
  }
}
