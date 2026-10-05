BEGIN;

CREATE TABLE IF NOT EXISTS item_definitions (
    item_id VARCHAR(64) PRIMARY KEY
        CHECK (item_id ~ '^[a-z0-9_]{1,64}$'),
    item_type VARCHAR(32) NOT NULL
        CHECK (item_type IN (
            'tank', 'tank_skin', 'avatar_fashion', 'profile_decoration',
            'vip_pass', 'material', 'assistant', 'consumable', 'bundle'
        )),
    display_name VARCHAR(128) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    image_asset_key TEXT NOT NULL DEFAULT '',
    presentation JSONB NOT NULL DEFAULT '{}'::jsonb,
    grant_spec JSONB NOT NULL DEFAULT '{}'::jsonb,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_shelves (
    shelf_id VARCHAR(64) PRIMARY KEY
        CHECK (shelf_id ~ '^[a-z0-9_]{1,64}$'),
    label VARCHAR(64) NOT NULL,
    layout VARCHAR(16) NOT NULL CHECK (layout IN ('small', 'large')),
    sort_order INTEGER NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_offers (
    offer_id VARCHAR(64) PRIMARY KEY
        CHECK (offer_id ~ '^[a-z0-9_]{1,64}$'),
    item_id VARCHAR(64) NOT NULL REFERENCES item_definitions(item_id),
    currency VARCHAR(16) NOT NULL
        CHECK (currency IN ('xu', 'locked_xu', 'silver')),
    price BIGINT NOT NULL CHECK (price >= 0),
    original_price BIGINT CHECK (original_price IS NULL OR original_price >= price),
    badges JSONB NOT NULL DEFAULT '[]'::jsonb,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    purchase_limit INTEGER CHECK (purchase_limit IS NULL OR purchase_limit > 0),
    max_quantity_per_order INTEGER NOT NULL DEFAULT 99
        CHECK (max_quantity_per_order BETWEEN 1 AND 999),
    giftable BOOLEAN NOT NULL DEFAULT FALSE,
    preview_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    sort_priority INTEGER NOT NULL DEFAULT 0,
    required_level INTEGER NOT NULL DEFAULT 1 CHECK (required_level >= 1),
    required_vip BOOLEAN NOT NULL DEFAULT FALSE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS shop_offer_shelves (
    offer_id VARCHAR(64) NOT NULL REFERENCES shop_offers(offer_id) ON DELETE CASCADE,
    shelf_id VARCHAR(64) NOT NULL REFERENCES shop_shelves(shelf_id) ON DELETE CASCADE,
    PRIMARY KEY (offer_id, shelf_id)
);

CREATE INDEX IF NOT EXISTS shop_offer_shelves_shelf_idx
    ON shop_offer_shelves(shelf_id, offer_id);
CREATE INDEX IF NOT EXISTS shop_offers_active_idx
    ON shop_offers(enabled, starts_at, ends_at);

CREATE TABLE IF NOT EXISTS shop_catalog_state (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    revision BIGINT NOT NULL DEFAULT 0 CHECK (revision >= 0),
    content_hash CHAR(64) NOT NULL DEFAULT repeat('0', 64),
    published_at TIMESTAMPTZ
);

INSERT INTO shop_catalog_state(singleton)
VALUES (TRUE)
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS inventory_stacks (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    item_id VARCHAR(64) NOT NULL REFERENCES item_definitions(item_id),
    quantity BIGINT NOT NULL CHECK (quantity > 0),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, item_id)
);

CREATE INDEX IF NOT EXISTS inventory_stacks_account_updated_idx
    ON inventory_stacks(account_id, updated_at DESC, item_id);

CREATE TABLE IF NOT EXISTS player_entitlements (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    entitlement_key VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, entitlement_key)
);

CREATE TABLE IF NOT EXISTS shop_purchase_counters (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    offer_id VARCHAR(64) NOT NULL REFERENCES shop_offers(offer_id),
    purchased_quantity BIGINT NOT NULL DEFAULT 0 CHECK (purchased_quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, offer_id)
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(128) NOT NULL,
    request_hash CHAR(64) NOT NULL,
    offer_id VARCHAR(64) NOT NULL REFERENCES shop_offers(offer_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    currency VARCHAR(16) NOT NULL
        CHECK (currency IN ('xu', 'locked_xu', 'silver')),
    unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
    total_price BIGINT NOT NULL CHECK (total_price >= 0),
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (account_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS purchase_orders_account_created_idx
    ON purchase_orders(account_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS economy_ledger (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    transaction_key VARCHAR(128) NOT NULL,
    entry_index SMALLINT NOT NULL CHECK (entry_index >= 0),
    asset_kind VARCHAR(16) NOT NULL
        CHECK (asset_kind IN ('currency', 'item', 'entitlement')),
    asset_key VARCHAR(64) NOT NULL,
    delta BIGINT NOT NULL CHECK (delta <> 0),
    balance_after BIGINT NOT NULL CHECK (balance_after >= 0),
    reason VARCHAR(32) NOT NULL,
    reference_type VARCHAR(32) NOT NULL,
    reference_id VARCHAR(128) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (transaction_key, entry_index)
);

CREATE INDEX IF NOT EXISTS economy_ledger_account_created_idx
    ON economy_ledger(account_id, created_at DESC, id DESC);

CREATE OR REPLACE FUNCTION deny_economy_ledger_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'economy_ledger is append-only';
END;
$$;

DROP TRIGGER IF EXISTS economy_ledger_append_only ON economy_ledger;
CREATE TRIGGER economy_ledger_append_only
BEFORE UPDATE OR DELETE ON economy_ledger
FOR EACH ROW EXECUTE FUNCTION deny_economy_ledger_mutation();

COMMIT;
