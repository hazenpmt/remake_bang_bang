import {
  catalogContentHash,
  loadPublishedCatalog,
  publishCatalog,
  validateCatalog,
} from "./shop-catalog.js";
import { contentAssetIds } from "./content-delivery.js";

export class ShopPublishingError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function publishingError(status, code, message) {
  throw new ShopPublishingError(status, code, message);
}

async function catalogRevision(client) {
  const result = await client.query(
    "SELECT revision FROM shop_catalog_state WHERE singleton",
  );
  return Number(result.rows[0]?.revision ?? 0);
}

async function assetsForCatalog(client, catalog) {
  const ids = contentAssetIds(catalog);
  if (ids.length === 0) {
    return [];
  }
  const result = await client.query(
    `SELECT asset_id, asset_kind, original_filename, media_type,
            byte_size::text, sha256, storage_key, state
       FROM content_assets
      WHERE asset_id = ANY($1::varchar[])
      ORDER BY asset_id`,
    [ids],
  );
  const found = new Set(result.rows.map((row) => row.asset_id));
  const missing = ids.filter((id) => !found.has(id));
  if (missing.length > 0) {
    publishingError(
      409,
      "CONTENT_ASSET_MISSING",
      `Catalog đang dùng asset chưa được upload: ${missing.join(", ")}.`,
    );
  }
  return result.rows;
}

function manifestAssets(rows) {
  return rows.map((row) => ({
    asset_id: row.asset_id,
    asset_kind: row.asset_kind,
    media_type: row.media_type,
    byte_size: Number(row.byte_size),
    sha256: row.sha256,
    storage_key: row.storage_key,
  }));
}

export async function readShopEditorState(client) {
  const revision = await catalogRevision(client);
  const liveCatalog = await loadPublishedCatalog(client);
  const draftResult = await client.query(
      `SELECT base_revision, catalog, updated_by::text, updated_at
         FROM shop_catalog_drafts WHERE singleton`,
    );
  const assets = await client.query(
      `SELECT asset_id, asset_kind, original_filename, media_type,
              byte_size::text, sha256, state, created_at, published_at
         FROM content_assets
        ORDER BY created_at DESC, asset_id
        LIMIT 500`,
    );
  const releases = await client.query(
      `SELECT release.id::text, release.catalog_revision, release.catalog_hash,
              release.published_by::text, account.username AS published_by_username,
              release.rollback_of::text, release.published_at
         FROM shop_catalog_releases release
         JOIN accounts account ON account.id = release.published_by
        ORDER BY release.id DESC
        LIMIT 50`,
    );
  const draft = draftResult.rows[0] ?? null;
  return {
    revision,
    live_catalog: liveCatalog,
    draft: draft
      ? {
        base_revision: Number(draft.base_revision),
        catalog: draft.catalog,
        updated_by: draft.updated_by,
        updated_at: draft.updated_at,
      }
      : null,
    assets: assets.rows.map((row) => ({
      ...row,
      byte_size: Number(row.byte_size),
      uri: `content://${row.asset_id}`,
    })),
    releases: releases.rows.map((row) => ({
      ...row,
      catalog_revision: Number(row.catalog_revision),
    })),
  };
}

export async function saveShopDraft(client, accountId, rawCatalog) {
  const catalog = validateCatalog(rawCatalog);
  const revision = await catalogRevision(client);
  await client.query(
    `INSERT INTO shop_catalog_drafts
       (singleton, base_revision, catalog, updated_by, updated_at)
     VALUES (TRUE, $1, $2::jsonb, $3, NOW())
     ON CONFLICT (singleton) DO UPDATE
       SET base_revision = EXCLUDED.base_revision,
           catalog = EXCLUDED.catalog,
           updated_by = EXCLUDED.updated_by,
           updated_at = NOW()`,
    [revision, JSON.stringify(catalog), accountId],
  );
  return { base_revision: revision, catalog };
}

async function insertRelease(client, accountId, catalog, result, assets, rollbackOf) {
  const manifest = {
    schema_version: 1,
    assets: manifestAssets(assets),
  };
  const inserted = await client.query(
    `INSERT INTO shop_catalog_releases
       (catalog_revision, catalog_hash, catalog, content_manifest,
        published_by, rollback_of)
     VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6)
     RETURNING id::text, catalog_revision, catalog_hash, published_at`,
    [
      result.revision,
      result.contentHash,
      JSON.stringify(catalog),
      JSON.stringify(manifest),
      accountId,
      rollbackOf,
    ],
  );
  const release = inserted.rows[0];
  const ids = assets.map((asset) => asset.asset_id);
  if (ids.length > 0) {
    await client.query(
      `UPDATE content_assets
          SET state = 'published', published_at = COALESCE(published_at, NOW()),
              updated_at = NOW()
        WHERE asset_id = ANY($1::varchar[])`,
      [ids],
    );
    await client.query(
      `INSERT INTO shop_catalog_release_assets (release_id, asset_id)
       SELECT $1, UNNEST($2::varchar[])`,
      [release.id, ids],
    );
  }
  await client.query(
    `UPDATE content_release_state
        SET active_release_id = $1, updated_at = NOW()
      WHERE singleton`,
    [release.id],
  );
  await client.query(
    `UPDATE shop_catalog_drafts
        SET base_revision = $1, updated_at = NOW()
      WHERE singleton`,
    [result.revision],
  );
  return {
    id: release.id,
    catalog_revision: Number(release.catalog_revision),
    catalog_hash: release.catalog_hash,
    published_at: release.published_at,
    asset_count: assets.length,
    rollback_of: rollbackOf == null ? null : String(rollbackOf),
  };
}

async function publishCatalogSnapshot(client, accountId, catalog, rollbackOf = null) {
  const assets = await assetsForCatalog(client, catalog);
  const result = await publishCatalog(client, catalog);
  if (!result.changed) {
    const current = await client.query(
      `SELECT id::text, catalog_revision, catalog_hash, published_at
         FROM shop_catalog_releases
        WHERE catalog_revision = $1`,
      [result.revision],
    );
    if (current.rowCount === 1) {
      return {
        changed: false,
        release: {
          ...current.rows[0],
          catalog_revision: Number(current.rows[0].catalog_revision),
          asset_count: assets.length,
        },
      };
    }
  }
  const release = await insertRelease(
    client,
    accountId,
    catalog,
    result,
    assets,
    rollbackOf,
  );
  return { changed: result.changed, release };
}

export async function publishShopDraft(client, accountId) {
  await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [7_304_202_608_14]);
  const draftResult = await client.query(
    `SELECT base_revision, catalog
       FROM shop_catalog_drafts
      WHERE singleton
      FOR UPDATE`,
  );
  if (draftResult.rowCount !== 1) {
    publishingError(409, "SHOP_DRAFT_REQUIRED", "Chưa có bản nháp Shop để phát hành.");
  }
  const currentRevision = await catalogRevision(client);
  if (Number(draftResult.rows[0].base_revision) !== currentRevision) {
    publishingError(
      409,
      "SHOP_DRAFT_STALE",
      "Catalog đã được phát hành ở nơi khác. Hãy tải lại trước khi publish.",
    );
  }
  const catalog = validateCatalog(draftResult.rows[0].catalog);
  return publishCatalogSnapshot(client, accountId, catalog);
}

export async function rollbackShopRelease(client, accountId, releaseId) {
  if (!/^[1-9]\d{0,18}$/.test(String(releaseId ?? ""))) {
    publishingError(400, "INVALID_RELEASE", "Bản phát hành không hợp lệ.");
  }
  await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [7_304_202_608_14]);
  const source = await client.query(
    "SELECT id, catalog FROM shop_catalog_releases WHERE id = $1",
    [releaseId],
  );
  if (source.rowCount !== 1) {
    publishingError(404, "RELEASE_NOT_FOUND", "Không tìm thấy bản phát hành.");
  }
  const catalog = validateCatalog(source.rows[0].catalog);
  const result = await publishCatalogSnapshot(
    client,
    accountId,
    catalog,
    source.rows[0].id,
  );
  await client.query(
    `INSERT INTO shop_catalog_drafts
       (singleton, base_revision, catalog, updated_by, updated_at)
     VALUES (TRUE, $1, $2::jsonb, $3, NOW())
     ON CONFLICT (singleton) DO UPDATE
       SET base_revision = EXCLUDED.base_revision,
           catalog = EXCLUDED.catalog,
           updated_by = EXCLUDED.updated_by,
           updated_at = NOW()`,
    [result.release.catalog_revision, JSON.stringify(catalog), accountId],
  );
  return result;
}

export function validatedCatalogHash(rawCatalog) {
  return catalogContentHash(validateCatalog(rawCatalog));
}
