BEGIN;

ALTER TABLE game_match_battle_participants
    ADD COLUMN IF NOT EXISTS skill_cooldown_ms JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMIT;
