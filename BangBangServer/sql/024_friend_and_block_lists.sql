BEGIN;

CREATE TABLE IF NOT EXISTS player_blocks (
    blocker_account_id BIGINT NOT NULL
        REFERENCES accounts(id) ON DELETE CASCADE,
    blocked_account_id BIGINT NOT NULL
        REFERENCES accounts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_account_id, blocked_account_id),
    CHECK (blocker_account_id <> blocked_account_id)
);

CREATE INDEX IF NOT EXISTS player_blocks_blocked_idx
    ON player_blocks (blocked_account_id, blocker_account_id);

COMMIT;
