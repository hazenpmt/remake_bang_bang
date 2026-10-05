BEGIN;

CREATE TABLE IF NOT EXISTS game_matches (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_a_room_id BIGINT NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
    team_b_room_id BIGINT REFERENCES game_rooms(id) ON DELETE CASCADE,
    is_test BOOLEAN NOT NULL DEFAULT FALSE,
    phase VARCHAR(16) NOT NULL DEFAULT 'confirming'
        CHECK (
            phase IN (
                'confirming',
                'selecting',
                'loading',
                'transition',
                'active',
                'cancelled'
            )
        ),
    map_key VARCHAR(64) NOT NULL DEFAULT 'random',
    confirmation_deadline TIMESTAMPTZ NOT NULL,
    selection_intro_until TIMESTAMPTZ,
    loading_started_at TIMESTAMPTZ,
    transition_started_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS game_matches_phase_deadline_idx
    ON game_matches(phase, confirmation_deadline, id);

CREATE TABLE IF NOT EXISTS game_match_participants (
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    team_no SMALLINT NOT NULL CHECK (team_no IN (1, 2)),
    slot_no SMALLINT NOT NULL CHECK (slot_no BETWEEN 1 AND 5),
    account_id BIGINT REFERENCES accounts(id) ON DELETE CASCADE,
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    display_name VARCHAR(64) NOT NULL,
    gender VARCHAR(16),
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    avatar_key VARCHAR(64),
    tank_key VARCHAR(64),
    tank_name VARCHAR(96),
    tank_preview_asset_key TEXT,
    tank_level INTEGER NOT NULL DEFAULT 1 CHECK (tank_level >= 1),
    equipped_skin_key VARCHAR(64),
    equipped_skin_name VARCHAR(96),
    equipped_skin_preview_asset_key TEXT,
    confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_at TIMESTAMPTZ,
    bot_confirm_at TIMESTAMPTZ,
    deployed BOOLEAN NOT NULL DEFAULT FALSE,
    deployed_at TIMESTAMPTZ,
    load_progress SMALLINT NOT NULL DEFAULT 0
        CHECK (load_progress BETWEEN 0 AND 100),
    load_ready BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (match_id, team_no, slot_no),
    UNIQUE (match_id, account_id),
    CHECK (
        (is_bot AND account_id IS NULL)
        OR (NOT is_bot AND account_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS game_match_participants_account_idx
    ON game_match_participants(account_id, match_id);

ALTER TABLE game_room_matchmaking
    ADD COLUMN IF NOT EXISTS match_id BIGINT
        REFERENCES game_matches(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS game_room_matchmaking_match_idx
    ON game_room_matchmaking(match_id);

COMMIT;
