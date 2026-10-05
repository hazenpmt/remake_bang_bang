BEGIN;

CREATE TABLE IF NOT EXISTS game_maps (
    map_key VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(96) NOT NULL,
    thumbnail_asset_path TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO game_maps (
    map_key,
    display_name,
    thumbnail_asset_path,
    sort_order,
    enabled
)
VALUES (
    'random',
    'Bản đồ ngẫu nhiên',
    'res://assets/ui/pvp_ready_room/maps/random.jpg',
    0,
    TRUE
)
ON CONFLICT (map_key) DO UPDATE
SET display_name = EXCLUDED.display_name,
    thumbnail_asset_path = EXCLUDED.thumbnail_asset_path,
    sort_order = EXCLUDED.sort_order,
    enabled = TRUE,
    updated_at = NOW();

COMMIT;
