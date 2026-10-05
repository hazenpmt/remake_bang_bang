import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const ID_PATTERN = /^[a-z0-9_]{1,64}$/;
const ITEM_TYPES = new Set([
  "tank",
  "tank_skin",
  "avatar_fashion",
  "profile_decoration",
  "vip_pass",
  "material",
  "assistant",
  "consumable",
  "bundle",
]);
const CURRENCIES = new Set(["xu", "locked_xu", "silver"]);
const LAYOUTS = new Set(["small", "large"]);
const BADGES = new Set(["hot", "new", "sale"]);
const STACK_ITEM_TYPES = new Set(["material", "consumable", "bundle"]);
const UNIQUE_ITEM_TYPES = new Set([
  "avatar_fashion",
  "profile_decoration",
  "assistant",
]);

export class CatalogValidationError extends Error {}

function fail(message) {
  throw new CatalogValidationError(message);
}

function identifier(value, label) {
  const result = String(value ?? "").trim();
  if (!ID_PATTERN.test(result)) {
    fail(`${label} phải khớp ${ID_PATTERN}.`);
  }
  return result;
}

function text(value, label, maximumLength, allowEmpty = false) {
  const result = String(value ?? "").normalize("NFKC").trim();
  const length = Array.from(result).length;
  if ((!allowEmpty && length === 0) || length > maximumLength) {
    fail(`${label} phải có ${allowEmpty ? "0-" : "1-"}${maximumLength} ký tự.`);
  }
  return result;
}

function integer(value, label, minimum, maximum, fallback = null) {
  if ((value == null || value === "") && fallback != null) {
    return fallback;
  }
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    fail(`${label} phải là số nguyên từ ${minimum} đến ${maximum}.`);
  }
  return value;
}

function nullableInteger(value, label, minimum, maximum) {
  return value == null ? null : integer(value, label, minimum, maximum);
}

function timestamp(value, label) {
  if (value == null || value === "") {
    return null;
  }
  const milliseconds = Date.parse(String(value));
  if (!Number.isFinite(milliseconds)) {
    fail(`${label} không phải thời gian ISO-8601 hợp lệ.`);
  }
  return new Date(milliseconds).toISOString();
}

function normalizeAssetPath(value, sourcePrefix) {
  const assetPath = String(value ?? "").trim().replaceAll("\\", "/");
  if (
    !assetPath ||
    assetPath.startsWith("res://") ||
    assetPath.startsWith("user://") ||
    assetPath.startsWith("content://") ||
    assetPath.startsWith("https://")
  ) {
    return assetPath;
  }
  if (assetPath.startsWith("http://") || path.posix.isAbsolute(assetPath)) {
    fail(`Đường dẫn ảnh không an toàn: ${assetPath}`);
  }
  const normalized = path.posix.normalize(
    sourcePrefix ? `${sourcePrefix}/${assetPath}` : assetPath,
  );
  if (normalized === ".." || normalized.startsWith("../")) {
    fail(`Đường dẫn ảnh đi ra ngoài shop_content: ${assetPath}`);
  }
  return normalized;
}

function normalizeGrant(itemId, itemType, value) {
  let grant = value;
  if (grant == null) {
    if (STACK_ITEM_TYPES.has(itemType)) {
      grant = { kind: "inventory_stack" };
    } else if (UNIQUE_ITEM_TYPES.has(itemType)) {
      grant = { kind: "inventory_unique" };
    } else {
      fail(`${itemId} (${itemType}) bắt buộc có grant cấu hình phía server.`);
    }
  }
  if (typeof grant !== "object" || Array.isArray(grant)) {
    fail(`grant của ${itemId} phải là object.`);
  }
  const kind = String(grant.kind ?? "");
  if (kind === "inventory_stack" || kind === "inventory_unique") {
    return { kind };
  }
  if (kind === "tank") {
    return {
      kind,
      tank_key: identifier(grant.tank_key, `${itemId}.grant.tank_key`),
    };
  }
  if (kind === "tank_skin") {
    return {
      kind,
      tank_key: identifier(grant.tank_key, `${itemId}.grant.tank_key`),
      skin_key: identifier(grant.skin_key, `${itemId}.grant.skin_key`),
    };
  }
  if (kind === "vip") {
    return {
      kind,
      duration_days: integer(
        grant.duration_days,
        `${itemId}.grant.duration_days`,
        1,
        3650,
      ),
    };
  }
  fail(`grant.kind không hỗ trợ ở ${itemId}: ${kind}`);
}

function normalizeDocument(document, sourcePrefix = "") {
  if (document == null || typeof document !== "object" || Array.isArray(document)) {
    fail("Catalog phải là một JSON object.");
  }
  const shelves = Array.isArray(document.shelves) ? document.shelves : [];
  const items = Array.isArray(document.items) ? document.items : [];
  const offers = Array.isArray(document.offers) ? document.offers : [];
  return {
    shelves: shelves.map((shelf, index) => ({ ...shelf, _source_index: index })),
    items: items.map((item) => ({
      ...item,
      image: normalizeAssetPath(item?.image, sourcePrefix),
    })),
    offers,
  };
}

function presentationFields(source, excluded) {
  const nested = (
    source.presentation
    && typeof source.presentation === "object"
    && !Array.isArray(source.presentation)
  ) ? source.presentation : {};
  return {
    ...nested,
    ...Object.fromEntries(
    Object.entries(source).filter(([key]) => !excluded.has(key) && !key.startsWith("_")),
    ),
  };
}

export function validateCatalog(source) {
  source = normalizeDocument(source);
  const shelfIds = new Set();
  const itemIds = new Set();
  const offerIds = new Set();

  const shelves = source.shelves.map((raw, index) => {
    const shelfId = identifier(raw.shelf_id, `shelves[${index}].shelf_id`);
    if (shelfIds.has(shelfId)) {
      fail(`shelf_id bị trùng: ${shelfId}`);
    }
    shelfIds.add(shelfId);
    const layout = String(raw.layout ?? "small");
    if (!LAYOUTS.has(layout)) {
      fail(`layout không hợp lệ ở shelf ${shelfId}.`);
    }
    return {
      shelf_id: shelfId,
      label: text(raw.label, `${shelfId}.label`, 64),
      layout,
      sort_order: integer(raw.sort_order ?? index, `${shelfId}.sort_order`, -100000, 100000),
      enabled: raw.enabled !== false,
    };
  });

  const items = source.items.map((raw, index) => {
    const itemId = identifier(raw.item_id, `items[${index}].item_id`);
    if (itemIds.has(itemId)) {
      fail(`item_id bị trùng: ${itemId}`);
    }
    itemIds.add(itemId);
    const itemType = String(raw.item_type ?? "");
    if (!ITEM_TYPES.has(itemType)) {
      fail(`item_type không hợp lệ ở ${itemId}: ${itemType}`);
    }
    return {
      item_id: itemId,
      item_type: itemType,
      name: text(raw.name, `${itemId}.name`, 128),
      description: text(raw.description, `${itemId}.description`, 2000, true),
      image: String(raw.image ?? ""),
      grant: normalizeGrant(itemId, itemType, raw.grant),
      enabled: raw.enabled !== false,
      presentation: presentationFields(
        raw,
        new Set([
          "item_id", "item_type", "name", "description", "image", "grant", "enabled",
          "presentation",
        ]),
      ),
    };
  });

  const offers = source.offers.map((raw, index) => {
    const offerId = identifier(raw.offer_id, `offers[${index}].offer_id`);
    if (offerIds.has(offerId)) {
      fail(`offer_id bị trùng: ${offerId}`);
    }
    offerIds.add(offerId);
    const itemId = identifier(raw.item_id, `${offerId}.item_id`);
    if (!itemIds.has(itemId)) {
      fail(`${offerId} tham chiếu item không tồn tại: ${itemId}`);
    }
    const currency = String(raw.currency ?? "");
    if (!CURRENCIES.has(currency)) {
      fail(`currency không hợp lệ ở ${offerId}: ${currency}`);
    }
    if (!Array.isArray(raw.shelf_ids) || raw.shelf_ids.length === 0) {
      fail(`${offerId} phải nằm trong ít nhất một shelf.`);
    }
    const normalizedShelfIds = [...new Set(raw.shelf_ids.map((value) =>
      identifier(value, `${offerId}.shelf_ids`),
    ))];
    for (const shelfId of normalizedShelfIds) {
      if (!shelfIds.has(shelfId)) {
        fail(`${offerId} tham chiếu shelf không tồn tại: ${shelfId}`);
      }
    }
    const badges = Array.isArray(raw.badges) ? [...new Set(raw.badges)] : [];
    for (const badge of badges) {
      if (!BADGES.has(badge)) {
        fail(`badge không hợp lệ ở ${offerId}: ${badge}`);
      }
    }
    const startsAt = timestamp(raw.start_at, `${offerId}.start_at`);
    const endsAt = timestamp(raw.end_at, `${offerId}.end_at`);
    if (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) {
      fail(`${offerId}.end_at phải sau start_at.`);
    }
    const price = integer(raw.price, `${offerId}.price`, 0, Number.MAX_SAFE_INTEGER);
    const originalPrice = nullableInteger(
      raw.original_price,
      `${offerId}.original_price`,
      price,
      Number.MAX_SAFE_INTEGER,
    );
    return {
      offer_id: offerId,
      item_id: itemId,
      shelf_ids: normalizedShelfIds,
      currency,
      price,
      original_price: originalPrice,
      badges,
      start_at: startsAt,
      end_at: endsAt,
      purchase_limit: nullableInteger(
        raw.purchase_limit,
        `${offerId}.purchase_limit`,
        1,
        1_000_000,
      ),
      max_quantity_per_order: integer(
        raw.max_quantity_per_order ?? 99,
        `${offerId}.max_quantity_per_order`,
        1,
        999,
      ),
      giftable: raw.giftable === true,
      preview_enabled: raw.preview_enabled === true,
      sort_priority: integer(
        raw.sort_priority ?? 0,
        `${offerId}.sort_priority`,
        -100000,
        100000,
      ),
      required_level: integer(
        raw.required_level ?? 1,
        `${offerId}.required_level`,
        1,
        999,
      ),
      required_vip: raw.required_vip === true,
      enabled: raw.enabled !== false,
    };
  });

  return { schema_version: 2, shelves, items, offers };
}

export async function loadPublishedCatalog(client) {
  const shelves = await client.query(
      `SELECT shelf_id, label, layout, sort_order, enabled
         FROM shop_shelves
        WHERE enabled
        ORDER BY sort_order, shelf_id`,
    );
  const items = await client.query(
      `SELECT item_id, item_type, display_name, description, image_asset_key,
              presentation, grant_spec, enabled
         FROM item_definitions
        WHERE enabled
        ORDER BY item_id`,
    );
  const offers = await client.query(
      `SELECT offer.offer_id, offer.item_id, offer.currency, offer.price,
              offer.original_price, offer.badges, offer.starts_at, offer.ends_at,
              offer.purchase_limit, offer.max_quantity_per_order,
              offer.giftable, offer.preview_enabled, offer.sort_priority,
              offer.required_level, offer.required_vip, offer.enabled,
              COALESCE(array_agg(link.shelf_id ORDER BY shelf.sort_order, link.shelf_id)
                FILTER (WHERE link.shelf_id IS NOT NULL), '{}') AS shelf_ids
         FROM shop_offers offer
         LEFT JOIN shop_offer_shelves link ON link.offer_id = offer.offer_id
        LEFT JOIN shop_shelves shelf ON shelf.shelf_id = link.shelf_id
        WHERE offer.enabled
        GROUP BY offer.offer_id
        ORDER BY offer.offer_id`,
    );
  return {
    schema_version: 2,
    shelves: shelves.rows,
    items: items.rows.map((row) => ({
      item_id: row.item_id,
      item_type: row.item_type,
      name: row.display_name,
      description: row.description,
      image: row.image_asset_key,
      grant: row.grant_spec,
      enabled: row.enabled,
      ...(row.presentation ?? {}),
    })),
    offers: offers.rows.map((row) => ({
      offer_id: row.offer_id,
      item_id: row.item_id,
      shelf_ids: row.shelf_ids,
      currency: row.currency,
      price: Number(row.price),
      original_price: row.original_price == null ? null : Number(row.original_price),
      badges: row.badges,
      start_at: row.starts_at,
      end_at: row.ends_at,
      purchase_limit: row.purchase_limit == null ? null : Number(row.purchase_limit),
      max_quantity_per_order: row.max_quantity_per_order,
      giftable: row.giftable,
      preview_enabled: row.preview_enabled,
      sort_priority: row.sort_priority,
      required_level: row.required_level,
      required_vip: row.required_vip,
      enabled: row.enabled,
    })),
  };
}

export async function loadCatalogDirectory(rootDirectory) {
  const root = path.resolve(rootDirectory);
  const base = normalizeDocument(
    JSON.parse(await readFile(path.join(root, "catalog.json"), "utf8")),
  );
  const merged = { shelves: [...base.shelves], items: [...base.items], offers: [...base.offers] };
  const packagesRoot = path.join(root, "packages");
  let entries = [];
  try {
    entries = await readdir(packagesRoot, { withFileTypes: true });
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  for (const entry of entries.filter((value) => value.isDirectory()).sort((a, b) =>
    a.name.localeCompare(b.name),
  )) {
    const manifestPath = path.join(packagesRoot, entry.name, "manifest.json");
    let raw;
    try {
      raw = JSON.parse(await readFile(manifestPath, "utf8"));
    } catch (error) {
      if (error?.code === "ENOENT") {
        continue;
      }
      throw error;
    }
    const document = normalizeDocument(raw, `packages/${entry.name}`);
    merged.shelves.push(...document.shelves);
    merged.items.push(...document.items);
    merged.offers.push(...document.offers);
  }
  return validateCatalog(merged);
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`,
    ).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function catalogContentHash(catalog) {
  return createHash("sha256").update(canonicalJson(catalog)).digest("hex");
}

export async function publishCatalog(client, catalog) {
  const contentHash = catalogContentHash(catalog);
  await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [7_304_202_608_13]);
  const state = await client.query(
    "SELECT revision, content_hash FROM shop_catalog_state WHERE singleton FOR UPDATE",
  );
  if (state.rows[0]?.content_hash === contentHash) {
    return { changed: false, revision: Number(state.rows[0].revision), contentHash };
  }

  await client.query("UPDATE shop_offers SET enabled = FALSE, updated_at = NOW()");
  await client.query("UPDATE shop_shelves SET enabled = FALSE, updated_at = NOW()");
  await client.query("UPDATE item_definitions SET enabled = FALSE, updated_at = NOW()");

  for (const item of catalog.items) {
    await client.query(
      `INSERT INTO item_definitions
         (item_id, item_type, display_name, description, image_asset_key,
          presentation, grant_spec, enabled)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
       ON CONFLICT (item_id) DO UPDATE
       SET item_type = EXCLUDED.item_type,
           display_name = EXCLUDED.display_name,
           description = EXCLUDED.description,
           image_asset_key = EXCLUDED.image_asset_key,
           presentation = EXCLUDED.presentation,
           grant_spec = EXCLUDED.grant_spec,
           enabled = EXCLUDED.enabled,
           updated_at = NOW()`,
      [
        item.item_id,
        item.item_type,
        item.name,
        item.description,
        item.image,
        JSON.stringify(item.presentation),
        JSON.stringify(item.grant),
        item.enabled,
      ],
    );
  }
  for (const shelf of catalog.shelves) {
    await client.query(
      `INSERT INTO shop_shelves (shelf_id, label, layout, sort_order, enabled)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (shelf_id) DO UPDATE
       SET label = EXCLUDED.label,
           layout = EXCLUDED.layout,
           sort_order = EXCLUDED.sort_order,
           enabled = EXCLUDED.enabled,
           updated_at = NOW()`,
      [shelf.shelf_id, shelf.label, shelf.layout, shelf.sort_order, shelf.enabled],
    );
  }
  for (const offer of catalog.offers) {
    await client.query(
      `INSERT INTO shop_offers
         (offer_id, item_id, currency, price, original_price, badges,
          starts_at, ends_at, purchase_limit, max_quantity_per_order,
          giftable, preview_enabled, sort_priority, required_level,
          required_vip, enabled)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9, $10,
               $11, $12, $13, $14, $15, $16)
       ON CONFLICT (offer_id) DO UPDATE
       SET item_id = EXCLUDED.item_id,
           currency = EXCLUDED.currency,
           price = EXCLUDED.price,
           original_price = EXCLUDED.original_price,
           badges = EXCLUDED.badges,
           starts_at = EXCLUDED.starts_at,
           ends_at = EXCLUDED.ends_at,
           purchase_limit = EXCLUDED.purchase_limit,
           max_quantity_per_order = EXCLUDED.max_quantity_per_order,
           giftable = EXCLUDED.giftable,
           preview_enabled = EXCLUDED.preview_enabled,
           sort_priority = EXCLUDED.sort_priority,
           required_level = EXCLUDED.required_level,
           required_vip = EXCLUDED.required_vip,
           enabled = EXCLUDED.enabled,
           updated_at = NOW()`,
      [
        offer.offer_id,
        offer.item_id,
        offer.currency,
        offer.price,
        offer.original_price,
        JSON.stringify(offer.badges),
        offer.start_at,
        offer.end_at,
        offer.purchase_limit,
        offer.max_quantity_per_order,
        offer.giftable,
        offer.preview_enabled,
        offer.sort_priority,
        offer.required_level,
        offer.required_vip,
        offer.enabled,
      ],
    );
  }

  await client.query("DELETE FROM shop_offer_shelves");
  for (const offer of catalog.offers) {
    for (const shelfId of offer.shelf_ids) {
      await client.query(
        `INSERT INTO shop_offer_shelves (offer_id, shelf_id)
         VALUES ($1, $2)`,
        [offer.offer_id, shelfId],
      );
    }
  }
  const updated = await client.query(
    `UPDATE shop_catalog_state
        SET revision = revision + 1,
            content_hash = $1,
            published_at = NOW()
      WHERE singleton
      RETURNING revision`,
    [contentHash],
  );
  return { changed: true, revision: Number(updated.rows[0].revision), contentHash };
}
