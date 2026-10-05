BEGIN;

ALTER TABLE game_match_battle_events
    ADD COLUMN IF NOT EXISTS event_key UUID;

CREATE UNIQUE INDEX IF NOT EXISTS game_match_battle_events_event_key_uq
    ON game_match_battle_events(event_key)
    WHERE event_key IS NOT NULL;

COMMIT;
