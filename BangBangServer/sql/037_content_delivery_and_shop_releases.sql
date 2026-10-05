CREATE TABLE content_assets (
  asset_id varchar(64) PRIMARY KEY CHECK (asset_id ~ '^[a-z0-9_]{1,64}$'),
  asset_kind varchar(24) NOT NULL CHECK (asset_kind IN ('image')),
  original_filename varchar(255) NOT NULL,
  media_type varchar(80) NOT NULL,
  byte_size bigint NOT NULL CHECK (byte_size > 0 AND byte_size <= 16777216),
  sha256 char(64) NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  storage_key varchar(255) NOT NULL,
  state varchar(16) NOT NULL DEFAULT 'draft'
    CHECK (state IN ('draft', 'published', 'retired')),
  uploaded_by bigint NOT NULL REFERENCES accounts(id),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  published_at timestamptz,
  UNIQUE (storage_key)
);

CREATE INDEX content_assets_state_created_idx
  ON content_assets (state, created_at DESC);

CREATE TABLE shop_catalog_drafts (
  singleton boolean PRIMARY KEY DEFAULT TRUE CHECK (singleton),
  base_revision bigint NOT NULL DEFAULT 0 CHECK (base_revision >= 0),
  catalog jsonb NOT NULL,
  updated_by bigint NOT NULL REFERENCES accounts(id),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE shop_catalog_releases (
  id bigserial PRIMARY KEY,
  catalog_revision bigint NOT NULL UNIQUE CHECK (catalog_revision > 0),
  catalog_hash char(64) NOT NULL CHECK (catalog_hash ~ '^[0-9a-f]{64}$'),
  catalog jsonb NOT NULL,
  content_manifest jsonb NOT NULL,
  published_by bigint NOT NULL REFERENCES accounts(id),
  rollback_of bigint REFERENCES shop_catalog_releases(id),
  published_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX shop_catalog_releases_published_idx
  ON shop_catalog_releases (published_at DESC, id DESC);

CREATE TABLE shop_catalog_release_assets (
  release_id bigint NOT NULL REFERENCES shop_catalog_releases(id) ON DELETE CASCADE,
  asset_id varchar(64) NOT NULL REFERENCES content_assets(asset_id),
  PRIMARY KEY (release_id, asset_id)
);

CREATE TABLE content_release_state (
  singleton boolean PRIMARY KEY DEFAULT TRUE CHECK (singleton),
  active_release_id bigint REFERENCES shop_catalog_releases(id),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

INSERT INTO content_release_state (singleton) VALUES (TRUE)
ON CONFLICT (singleton) DO NOTHING;
