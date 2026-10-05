import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { config } from "./config.js";

const ASSET_ID_PATTERN = /^[a-z0-9_]{1,64}$/;
const CONTENT_URI_PATTERN = /^content:\/\/([a-z0-9_]{1,64})$/;

const IMAGE_FORMATS = Object.freeze([
  {
    mediaType: "image/png",
    extension: ".png",
    matches: (buffer) => buffer.length >= 8
      && buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])),
  },
  {
    mediaType: "image/jpeg",
    extension: ".jpg",
    matches: (buffer) => buffer.length >= 3
      && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff,
  },
  {
    mediaType: "image/webp",
    extension: ".webp",
    matches: (buffer) => buffer.length >= 12
      && buffer.subarray(0, 4).toString("ascii") === "RIFF"
      && buffer.subarray(8, 12).toString("ascii") === "WEBP",
  },
]);

export class ContentDeliveryError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function contentError(status, code, message) {
  throw new ContentDeliveryError(status, code, message);
}

function safeFilename(value) {
  const result = path.basename(String(value ?? "asset")).normalize("NFKC").trim();
  return result.slice(0, 255) || "asset";
}

function detectImage(buffer) {
  return IMAGE_FORMATS.find((format) => format.matches(buffer)) ?? null;
}

export function contentAssetIds(catalog) {
  const ids = new Set();
  for (const item of catalog.items ?? []) {
    const presentation = item.presentation && typeof item.presentation === "object"
      ? item.presentation
      : {};
    const skills = Array.isArray(item.skills)
      ? item.skills
      : (Array.isArray(presentation.skills) ? presentation.skills : []);
    for (const value of [item.image, ...skills]) {
      const match = CONTENT_URI_PATTERN.exec(String(value ?? ""));
      if (match) {
        ids.add(match[1]);
      }
    }
  }
  return [...ids].sort();
}

export async function saveImageAsset({
  assetId,
  originalFilename,
  body,
  uploadedBy,
  query,
}) {
  const normalizedId = String(assetId ?? "").trim();
  if (!ASSET_ID_PATTERN.test(normalizedId)) {
    contentError(400, "INVALID_ASSET_ID", "asset_id chỉ được gồm chữ thường, số và dấu gạch dưới.");
  }
  if (!Buffer.isBuffer(body) || body.length === 0) {
    contentError(400, "EMPTY_ASSET", "File ảnh đang trống.");
  }
  if (body.length > config.contentMaxImageBytes) {
    contentError(413, "ASSET_TOO_LARGE", "Ảnh vượt quá giới hạn dung lượng cho phép.");
  }
  const format = detectImage(body);
  if (!format) {
    contentError(415, "UNSUPPORTED_ASSET", "Chỉ nhận ảnh PNG, JPEG hoặc WebP gốc.");
  }

  const sha256 = createHash("sha256").update(body).digest("hex");
  await query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [sha256]);
  const duplicate = await query(
    "SELECT asset_id FROM content_assets WHERE sha256 = $1 ORDER BY asset_id LIMIT 1",
    [sha256],
  );
  if (duplicate.rowCount === 1 && duplicate.rows[0].asset_id !== normalizedId) {
    contentError(
      409,
      "ASSET_DUPLICATE",
      `File này đã có với asset_id ${duplicate.rows[0].asset_id}; hãy dùng lại URI đó.`,
    );
  }
  const storageKey = `images/${sha256}${format.extension}`;
  const absolutePath = path.resolve(config.contentStorageRoot, storageKey);
  const storageRoot = path.resolve(config.contentStorageRoot) + path.sep;
  if (!absolutePath.startsWith(storageRoot)) {
    contentError(400, "INVALID_STORAGE_PATH", "Đường dẫn lưu nội dung không hợp lệ.");
  }
  await mkdir(path.dirname(absolutePath), { recursive: true });
  try {
    await writeFile(absolutePath, body, { flag: "wx" });
  } catch (error) {
    if (error?.code !== "EEXIST") {
      throw error;
    }
  }

  const existing = await query(
    "SELECT sha256 FROM content_assets WHERE asset_id = $1",
    [normalizedId],
  );
  if (existing.rowCount === 1 && existing.rows[0].sha256 !== sha256) {
    contentError(
      409,
      "ASSET_ID_EXISTS",
      "asset_id đã tồn tại với file khác. Hãy dùng asset_id mới để không ghi đè nội dung đã phát hành.",
    );
  }

  const result = await query(
    `INSERT INTO content_assets
       (asset_id, asset_kind, original_filename, media_type, byte_size,
        sha256, storage_key, state, uploaded_by)
     VALUES ($1, 'image', $2, $3, $4, $5, $6, 'draft', $7)
     ON CONFLICT (asset_id) DO UPDATE
       SET original_filename = EXCLUDED.original_filename,
           updated_at = NOW()
     RETURNING asset_id, asset_kind, original_filename, media_type,
               byte_size::text, sha256, storage_key, state, created_at, updated_at`,
    [
      normalizedId,
      safeFilename(originalFilename),
      format.mediaType,
      body.length,
      sha256,
      storageKey,
      uploadedBy,
    ],
  );
  return result.rows[0];
}

export function materializeManifest(manifest, baseUrl) {
  const normalizedBase = String(baseUrl ?? "").replace(/\/+$/, "");
  return {
    ...manifest,
    assets: (manifest.assets ?? []).map((asset) => ({
      ...asset,
      url: `${normalizedBase}/content/${asset.storage_key}`,
    })),
  };
}

export async function readPublishedManifest(query) {
  const result = await query(
    `SELECT release.id::text AS release_id, release.catalog_revision,
            release.catalog_hash, release.content_manifest, release.published_at
       FROM content_release_state state
       LEFT JOIN shop_catalog_releases release ON release.id = state.active_release_id
      WHERE state.singleton`,
  );
  const release = result.rows[0];
  if (!release?.release_id) {
    return {
      schema_version: 1,
      release_id: null,
      catalog_revision: 0,
      catalog_hash: "",
      published_at: null,
      assets: [],
    };
  }
  return {
    schema_version: 1,
    release_id: release.release_id,
    catalog_revision: Number(release.catalog_revision),
    catalog_hash: release.catalog_hash,
    published_at: release.published_at,
    assets: release.content_manifest?.assets ?? [],
  };
}

export async function readContentFile(storageKey, query) {
  const normalized = String(storageKey ?? "").replaceAll("\\", "/");
  if (!/^images\/[0-9a-f]{64}\.(png|jpg|webp)$/.test(normalized)) {
    contentError(404, "CONTENT_NOT_FOUND", "Không tìm thấy nội dung.");
  }
  const result = await query(
    `SELECT media_type, byte_size::text, sha256, storage_key
       FROM content_assets
      WHERE storage_key = $1 AND state = 'published'`,
    [normalized],
  );
  if (result.rowCount !== 1) {
    contentError(404, "CONTENT_NOT_FOUND", "Không tìm thấy nội dung.");
  }
  const absolutePath = path.resolve(config.contentStorageRoot, normalized);
  const storageRoot = path.resolve(config.contentStorageRoot) + path.sep;
  if (!absolutePath.startsWith(storageRoot)) {
    contentError(404, "CONTENT_NOT_FOUND", "Không tìm thấy nội dung.");
  }
  return { ...result.rows[0], body: await readFile(absolutePath) };
}
