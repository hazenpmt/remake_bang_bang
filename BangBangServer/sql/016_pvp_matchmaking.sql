BEGIN;

ALTER TABLE game_rooms
    DROP CONSTRAINT IF EXISTS game_rooms_status_check;

ALTER TABLE game_rooms
    ADD CONSTRAINT game_rooms_status_check
    CHECK (status IN ('waiting', 'matching', 'running'));

CREATE TABLE IF NOT EXISTS game_room_matchmaking (
    room_id BIGINT PRIMARY KEY REFERENCES game_rooms(id) ON DELETE CASCADE,
    state VARCHAR(16) NOT NULL DEFAULT 'searching'
        CHECK (state IN ('searching', 'matched', 'cancelled')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estimated_seconds INTEGER NOT NULL DEFAULT 30
        CHECK (estimated_seconds BETWEEN 1 AND 3600),
    ally_bot_count INTEGER NOT NULL DEFAULT 0
        CHECK (ally_bot_count BETWEEN 0 AND 5),
    enemy_bot_count INTEGER NOT NULL DEFAULT 0
        CHECK (enemy_bot_count BETWEEN 0 AND 5),
    matched_room_id BIGINT REFERENCES game_rooms(id) ON DELETE SET NULL,
    matched_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS game_room_matchmaking_state_started_idx
    ON game_room_matchmaking(state, started_at, room_id);

COMMIT;
