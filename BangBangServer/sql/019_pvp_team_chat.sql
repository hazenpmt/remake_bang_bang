BEGIN;

CREATE TABLE IF NOT EXISTS game_match_team_messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    team_no SMALLINT NOT NULL CHECK (team_no IN (1, 2)),
    sender_account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    body VARCHAR(120) NOT NULL CHECK (char_length(body) BETWEEN 1 AND 120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS game_match_team_messages_channel_idx
    ON game_match_team_messages(match_id, team_no, id);

COMMIT;
