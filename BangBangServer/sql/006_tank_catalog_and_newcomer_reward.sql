BEGIN;

ALTER TABLE tanks
    ADD COLUMN IF NOT EXISTS max_level SMALLINT NOT NULL DEFAULT 6
        CHECK (max_level BETWEEN 1 AND 99),
    ADD COLUMN IF NOT EXISTS damage_type VARCHAR(16) NOT NULL DEFAULT 'physical'
        CHECK (damage_type IN ('physical', 'energy')),
    ADD COLUMN IF NOT EXISTS role_key VARCHAR(32),
    ADD COLUMN IF NOT EXISTS quality_key VARCHAR(16),
    ADD COLUMN IF NOT EXISTS difficulty SMALLINT
        CHECK (difficulty BETWEEN 1 AND 3),
    ADD COLUMN IF NOT EXISTS avatar_asset_key TEXT,
    ADD COLUMN IF NOT EXISTS preview_asset_key TEXT,
    ADD COLUMN IF NOT EXISTS thumbnail_asset_key TEXT;

CREATE TABLE IF NOT EXISTS tank_level_stats (
    tank_id BIGINT NOT NULL REFERENCES tanks(id) ON DELETE CASCADE,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 99),
    hit_points INTEGER CHECK (hit_points >= 0),
    basic_attack_damage INTEGER CHECK (basic_attack_damage >= 0),
    penetration INTEGER CHECK (penetration >= 0),
    physical_armor INTEGER CHECK (physical_armor >= 0),
    energy_shield INTEGER CHECK (energy_shield >= 0),
    move_speed INTEGER CHECK (move_speed >= 0),
    fire_rate INTEGER CHECK (fire_rate >= 0),
    attack_range INTEGER CHECK (attack_range >= 0),
    PRIMARY KEY (tank_id, level)
);

CREATE TABLE IF NOT EXISTS tank_skills (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tank_id BIGINT NOT NULL REFERENCES tanks(id) ON DELETE CASCADE,
    skill_key VARCHAR(64) NOT NULL,
    slot_index SMALLINT NOT NULL CHECK (slot_index BETWEEN 1 AND 12),
    display_name VARCHAR(96),
    icon_asset_key TEXT NOT NULL,
    base_damage INTEGER CHECK (base_damage >= 0),
    damage_per_tank_level INTEGER CHECK (damage_per_tank_level >= 0),
    cooldown_ms INTEGER CHECK (cooldown_ms >= 0),
    description TEXT,
    UNIQUE (tank_id, skill_key),
    UNIQUE (tank_id, slot_index)
);

CREATE TABLE IF NOT EXISTS tank_skins (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tank_id BIGINT NOT NULL REFERENCES tanks(id) ON DELETE CASCADE,
    skin_key VARCHAR(64) NOT NULL,
    display_name VARCHAR(96) NOT NULL,
    quality_key VARCHAR(16),
    avatar_asset_key TEXT,
    preview_asset_key TEXT,
    stat_modifiers JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (tank_id, skin_key)
);

CREATE UNIQUE INDEX IF NOT EXISTS tank_skins_one_default_uq
    ON tank_skins(tank_id)
    WHERE is_default;

CREATE TABLE IF NOT EXISTS player_tank_skins (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    tank_skin_id BIGINT NOT NULL REFERENCES tank_skins(id),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, tank_skin_id)
);

CREATE TABLE IF NOT EXISTS player_rewards (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    reward_key VARCHAR(64) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'claimed')),
    offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    claimed_at TIMESTAMPTZ,
    PRIMARY KEY (account_id, reward_key),
    CHECK (
        (status = 'pending' AND claimed_at IS NULL)
        OR (status = 'claimed' AND claimed_at IS NOT NULL)
    )
);

INSERT INTO tanks (
    tank_key,
    display_name,
    max_level,
    damage_type,
    role_key,
    avatar_asset_key,
    preview_asset_key,
    thumbnail_asset_key
)
VALUES (
    'gangtiexia03',
    'Iron Man',
    6,
    'physical',
    'dps',
    'zh_CN/avatar/gangtiexia03.png',
    'zh_CN/avatar/300/gangtiexia03.png',
    'zh_CN/avatar/head/gangtiexia03.png'
)
ON CONFLICT (tank_key) DO UPDATE
SET display_name = EXCLUDED.display_name,
    max_level = EXCLUDED.max_level,
    damage_type = EXCLUDED.damage_type,
    role_key = EXCLUDED.role_key,
    avatar_asset_key = EXCLUDED.avatar_asset_key,
    preview_asset_key = EXCLUDED.preview_asset_key,
    thumbnail_asset_key = EXCLUDED.thumbnail_asset_key,
    enabled = TRUE;

INSERT INTO tank_skills (
    tank_id,
    skill_key,
    slot_index,
    icon_asset_key
)
SELECT id, skill_key, slot_index, icon_asset_key
FROM tanks
CROSS JOIN (
    VALUES
        ('skill_tiejia', 1, 'zh_CN/icon/skills/skill_tiejia.jpg'),
        ('skill_hongzha', 2, 'zh_CN/icon/skills/skill_hongzha.jpg'),
        ('skill_penshe', 3, 'zh_CN/icon/skills/skill_penshe.jpg')
) AS source(skill_key, slot_index, icon_asset_key)
WHERE tanks.tank_key = 'gangtiexia03'
ON CONFLICT (tank_id, skill_key) DO UPDATE
SET slot_index = EXCLUDED.slot_index,
    icon_asset_key = EXCLUDED.icon_asset_key;

INSERT INTO tank_skins (
    tank_id,
    skin_key,
    display_name,
    avatar_asset_key,
    preview_asset_key,
    is_default
)
SELECT
    id,
    'gangtiexia03_default',
    'Iron Man',
    'zh_CN/avatar/gangtiexia03.png',
    'zh_CN/avatar/300/gangtiexia03.png',
    TRUE
FROM tanks
WHERE tank_key = 'gangtiexia03'
ON CONFLICT (tank_id, skin_key) DO UPDATE
SET display_name = EXCLUDED.display_name,
    avatar_asset_key = EXCLUDED.avatar_asset_key,
    preview_asset_key = EXCLUDED.preview_asset_key,
    is_default = TRUE,
    enabled = TRUE;

-- Hồ sơ đã tồn tại trước tính năng này không phải tài khoản tân thủ mới.
INSERT INTO player_rewards (
    account_id,
    reward_key,
    status,
    claimed_at
)
SELECT
    account_id,
    'newcomer_iron_man',
    'claimed',
    NOW()
FROM player_profiles
ON CONFLICT (account_id, reward_key) DO NOTHING;

COMMIT;
