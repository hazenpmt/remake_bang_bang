BEGIN;

INSERT INTO tank_level_stats (
    tank_id,
    level,
    hit_points,
    basic_attack_damage,
    penetration,
    physical_armor,
    energy_shield,
    move_speed,
    fire_rate,
    attack_range
)
SELECT
    tank.id,
    1,
    2325,
    238,
    30,
    150,
    150,
    170,
    66,
    480
FROM tanks tank
WHERE tank.tank_key = 'gangtiexia03'
ON CONFLICT (tank_id, level) DO UPDATE
SET hit_points = EXCLUDED.hit_points,
    basic_attack_damage = EXCLUDED.basic_attack_damage,
    penetration = EXCLUDED.penetration,
    physical_armor = EXCLUDED.physical_armor,
    energy_shield = EXCLUDED.energy_shield,
    move_speed = EXCLUDED.move_speed,
    fire_rate = EXCLUDED.fire_rate,
    attack_range = EXCLUDED.attack_range;

CREATE TABLE IF NOT EXISTS player_tank_stat_bonuses (
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    tank_id BIGINT NOT NULL REFERENCES tanks(id) ON DELETE CASCADE,
    source_key VARCHAR(64) NOT NULL,
    hit_points INTEGER NOT NULL DEFAULT 0,
    basic_attack_damage INTEGER NOT NULL DEFAULT 0,
    penetration INTEGER NOT NULL DEFAULT 0,
    physical_armor INTEGER NOT NULL DEFAULT 0,
    energy_shield INTEGER NOT NULL DEFAULT 0,
    move_speed INTEGER NOT NULL DEFAULT 0,
    fire_rate INTEGER NOT NULL DEFAULT 0,
    attack_range INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, tank_id, source_key),
    CHECK (
        hit_points >= 0
        AND basic_attack_damage >= 0
        AND penetration >= 0
        AND physical_armor >= 0
        AND energy_shield >= 0
        AND move_speed >= 0
        AND fire_rate >= 0
        AND attack_range >= 0
    )
);

COMMIT;
