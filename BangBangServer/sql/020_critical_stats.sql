BEGIN;

ALTER TABLE tank_level_stats
    ADD COLUMN IF NOT EXISTS critical_chance_basis_points INTEGER
        NOT NULL DEFAULT 500,
    ADD COLUMN IF NOT EXISTS critical_damage_basis_points INTEGER
        NOT NULL DEFAULT 15000;

ALTER TABLE tank_level_stats
    DROP CONSTRAINT IF EXISTS tank_level_stats_critical_chance_range,
    ADD CONSTRAINT tank_level_stats_critical_chance_range
        CHECK (
            critical_chance_basis_points >= 0
            AND critical_chance_basis_points <= 10000
        ),
    DROP CONSTRAINT IF EXISTS tank_level_stats_critical_damage_nonnegative,
    ADD CONSTRAINT tank_level_stats_critical_damage_nonnegative
        CHECK (critical_damage_basis_points >= 0);

UPDATE tank_level_stats
SET critical_chance_basis_points = 500,
    critical_damage_basis_points = 15000;

COMMIT;
