BEGIN;

CREATE SEQUENCE IF NOT EXISTS game_room_code_seq START WITH 1000000;

CREATE TABLE IF NOT EXISTS game_rooms (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_code BIGINT NOT NULL UNIQUE DEFAULT nextval('game_room_code_seq'),
    tab_key VARCHAR(16) NOT NULL
        CHECK (tab_key IN ('event', 'solo', 'rank', 'guild', 'test')),
    room_name VARCHAR(40) NOT NULL,
    mode_key VARCHAR(24) NOT NULL DEFAULT 'free',
    map_key VARCHAR(64) NOT NULL DEFAULT 'random',
    max_players INTEGER NOT NULL DEFAULT 5
        CHECK (max_players BETWEEN 1 AND 5),
    status VARCHAR(16) NOT NULL DEFAULT 'waiting'
        CHECK (status IN ('waiting', 'running')),
    is_test BOOLEAN NOT NULL DEFAULT FALSE,
    created_by_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS game_rooms_tab_status_idx
    ON game_rooms(tab_key, status, created_at, id);

CREATE TABLE IF NOT EXISTS game_room_members (
    room_id BIGINT NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL UNIQUE REFERENCES accounts(id) ON DELETE CASCADE,
    join_order BIGINT GENERATED ALWAYS AS IDENTITY,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_id, account_id)
);

CREATE INDEX IF NOT EXISTS game_room_members_room_order_idx
    ON game_room_members(room_id, join_order);

INSERT INTO game_rooms (
    room_code,
    tab_key,
    room_name,
    mode_key,
    map_key,
    max_players,
    status,
    is_test
)
VALUES
    (1001, 'test', 'PvP Bot Test - sandbox', 'free', 'random', 5, 'waiting', TRUE),
    (268435491, 'test', 'PvP #20', 'free', 'bo_sua_chay_nhanh', 2, 'running', TRUE)
ON CONFLICT (room_code) DO UPDATE
SET tab_key = EXCLUDED.tab_key,
    room_name = EXCLUDED.room_name,
    mode_key = EXCLUDED.mode_key,
    map_key = EXCLUDED.map_key,
    max_players = EXCLUDED.max_players,
    status = EXCLUDED.status,
    is_test = TRUE,
    updated_at = NOW();

COMMIT;
