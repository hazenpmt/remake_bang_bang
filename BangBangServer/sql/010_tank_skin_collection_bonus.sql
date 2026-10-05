BEGIN;

CREATE TABLE IF NOT EXISTS tank_skin_collection_rules (
    id BIGSERIAL PRIMARY KEY,
    rule_key TEXT NOT NULL UNIQUE,
    sort_order INTEGER NOT NULL,
    requirement_type TEXT NOT NULL
        CHECK (requirement_type IN ('quality', 'distinct_quality_count')),
    required_quality TEXT,
    required_distinct_quality_count INTEGER NOT NULL DEFAULT 0
        CHECK (required_distinct_quality_count >= 0),
    requires_sss BOOLEAN NOT NULL DEFAULT FALSE,
    hit_points_percent INTEGER NOT NULL DEFAULT 0
        CHECK (hit_points_percent >= 0),
    attack_percent INTEGER NOT NULL DEFAULT 0
        CHECK (attack_percent >= 0),
    frame_tier TEXT,
    revive_speed_percent INTEGER NOT NULL DEFAULT 0
        CHECK (revive_speed_percent >= 0),
    revive_duration_seconds INTEGER NOT NULL DEFAULT 0
        CHECK (revive_duration_seconds >= 0),
    enabled BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO tank_skin_collection_rules (
    rule_key,
    sort_order,
    requirement_type,
    required_quality,
    required_distinct_quality_count,
    requires_sss,
    hit_points_percent,
    attack_percent,
    frame_tier,
    revive_speed_percent,
    revive_duration_seconds,
    enabled
)
VALUES
    ('quality_a', 10, 'quality', 'A', 0, FALSE, 2, 0, NULL, 0, 0, TRUE),
    ('quality_s', 20, 'quality', 'S', 0, FALSE, 0, 2, NULL, 0, 0, TRUE),
    ('quality_ss', 30, 'quality', 'SS', 0, FALSE, 6, 0, NULL, 0, 0, TRUE),
    ('quality_sss', 40, 'quality', 'SSS', 0, FALSE, 0, 6, NULL, 0, 0, TRUE),
    ('distinct_2', 50, 'distinct_quality_count', NULL, 2, FALSE, 2, 2, 'purple', 0, 0, TRUE),
    ('distinct_3_sss', 60, 'distinct_quality_count', NULL, 3, TRUE, 0, 0, 'orange', 0, 0, TRUE),
    ('distinct_4', 70, 'distinct_quality_count', NULL, 4, FALSE, 0, 0, NULL, 100, 3, TRUE)
ON CONFLICT (rule_key) DO UPDATE
SET sort_order = EXCLUDED.sort_order,
    requirement_type = EXCLUDED.requirement_type,
    required_quality = EXCLUDED.required_quality,
    required_distinct_quality_count = EXCLUDED.required_distinct_quality_count,
    requires_sss = EXCLUDED.requires_sss,
    hit_points_percent = EXCLUDED.hit_points_percent,
    attack_percent = EXCLUDED.attack_percent,
    frame_tier = EXCLUDED.frame_tier,
    revive_speed_percent = EXCLUDED.revive_speed_percent,
    revive_duration_seconds = EXCLUDED.revive_duration_seconds,
    enabled = EXCLUDED.enabled;

COMMIT;
