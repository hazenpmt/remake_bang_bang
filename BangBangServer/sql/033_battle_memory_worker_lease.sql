BEGIN;

ALTER TABLE game_matches
    ADD COLUMN IF NOT EXISTS battle_worker_id VARCHAR(96),
    ADD COLUMN IF NOT EXISTS battle_worker_epoch BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS battle_worker_lease_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS battle_checkpoint_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS game_matches_battle_worker_discovery_idx
    ON game_matches(phase, is_test, battle_worker_lease_until, id)
    WHERE phase = 'active' AND NOT is_test;

COMMIT;
