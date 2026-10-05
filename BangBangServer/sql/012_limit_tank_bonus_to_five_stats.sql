BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM player_tank_stat_bonuses
        WHERE move_speed <> 0
           OR fire_rate <> 0
           OR attack_range <> 0
    ) THEN
        RAISE EXCEPTION
            'Cannot remove unsupported tank bonus columns while non-zero data exists';
    END IF;
END
$$;

ALTER TABLE player_tank_stat_bonuses
    DROP COLUMN move_speed,
    DROP COLUMN fire_rate,
    DROP COLUMN attack_range;

COMMIT;
