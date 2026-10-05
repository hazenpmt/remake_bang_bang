BEGIN;

ALTER TABLE player_profiles
    ALTER COLUMN display_name TYPE VARCHAR(10);

ALTER TABLE player_profiles
    DROP CONSTRAINT IF EXISTS player_profiles_display_name_format_ck;

ALTER TABLE player_profiles
    ADD CONSTRAINT player_profiles_display_name_format_ck CHECK (
        CHAR_LENGTH(display_name) BETWEEN 3 AND 10
        AND display_name = BTRIM(display_name)
        AND display_name !~ '[[:space:]]{2,}'
        AND display_name !~ '^[0-9]+$'
        AND display_name !~ '[^[:alnum:] ]'
    );

COMMIT;
