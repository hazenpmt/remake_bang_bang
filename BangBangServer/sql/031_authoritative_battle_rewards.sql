BEGIN;

ALTER TABLE game_matches
    ADD COLUMN IF NOT EXISTS reward_settled_at TIMESTAMPTZ;

ALTER TABLE economy_ledger
    DROP CONSTRAINT IF EXISTS economy_ledger_asset_kind_check;
ALTER TABLE economy_ledger
    ADD CONSTRAINT economy_ledger_asset_kind_check
    CHECK (asset_kind IN ('currency', 'item', 'entitlement', 'experience'));

-- This is permanent audit history. IDs are intentionally retained as values
-- rather than cascading foreign keys, so deleting a room cannot erase rewards.
CREATE TABLE IF NOT EXISTS game_match_battle_rewards (
    match_id BIGINT NOT NULL,
    team_no SMALLINT NOT NULL CHECK (team_no IN (1, 2)),
    slot_no SMALLINT NOT NULL CHECK (slot_no BETWEEN 1 AND 5),
    account_id BIGINT NOT NULL,
    outcome VARCHAR(8) NOT NULL CHECK (outcome IN ('win', 'lose', 'draw')),
    tank_key VARCHAR(64) NOT NULL,
    kills INTEGER NOT NULL CHECK (kills >= 0),
    deaths INTEGER NOT NULL CHECK (deaths >= 0),
    assists INTEGER NOT NULL CHECK (assists >= 0),
    experience_reward BIGINT NOT NULL CHECK (experience_reward > 0),
    silver_reward BIGINT NOT NULL CHECK (silver_reward >= 0),
    level_before INTEGER NOT NULL CHECK (level_before >= 1),
    level_after INTEGER NOT NULL CHECK (level_after >= level_before),
    experience_before BIGINT NOT NULL CHECK (experience_before >= 0),
    experience_after BIGINT NOT NULL CHECK (experience_after >= 0),
    silver_before BIGINT NOT NULL CHECK (silver_before >= 0),
    silver_after BIGINT NOT NULL CHECK (silver_after >= silver_before),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (match_id, team_no, slot_no),
    UNIQUE (match_id, account_id)
);

CREATE INDEX IF NOT EXISTS game_match_battle_rewards_account_created_idx
    ON game_match_battle_rewards(account_id, created_at DESC, match_id DESC);

CREATE OR REPLACE FUNCTION deny_battle_reward_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'game_match_battle_rewards is append-only';
END;
$$;

DROP TRIGGER IF EXISTS game_match_battle_rewards_append_only
    ON game_match_battle_rewards;
CREATE TRIGGER game_match_battle_rewards_append_only
BEFORE UPDATE OR DELETE ON game_match_battle_rewards
FOR EACH ROW EXECUTE FUNCTION deny_battle_reward_mutation();

COMMIT;
