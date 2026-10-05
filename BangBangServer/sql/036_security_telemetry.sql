BEGIN;

CREATE TABLE IF NOT EXISTS security_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type VARCHAR(96) NOT NULL,
    severity VARCHAR(16) NOT NULL,
    source VARCHAR(32) NOT NULL,
    node_id VARCHAR(96) NOT NULL,
    account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    session_id BIGINT REFERENCES sessions(id) ON DELETE SET NULL,
    match_id BIGINT REFERENCES game_matches(id) ON DELETE SET NULL,
    route VARCHAR(160),
    source_ip_hash CHAR(64),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (severity IN ('info', 'low', 'medium', 'high', 'critical')),
    CHECK (source IN ('http', 'websocket', 'battle', 'economy', 'system')),
    CHECK (octet_length(details::text) <= 8192)
);

CREATE INDEX IF NOT EXISTS security_events_occurred_idx
    ON security_events(occurred_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS security_events_severity_occurred_idx
    ON security_events(severity, occurred_at DESC);
CREATE INDEX IF NOT EXISTS security_events_account_occurred_idx
    ON security_events(account_id, occurred_at DESC)
    WHERE account_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS security_events_type_occurred_idx
    ON security_events(event_type, occurred_at DESC);

CREATE OR REPLACE FUNCTION deny_security_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'security_events is append-only';
END;
$$;

DROP TRIGGER IF EXISTS security_events_append_only ON security_events;
CREATE TRIGGER security_events_append_only
BEFORE UPDATE OR DELETE ON security_events
FOR EACH ROW EXECUTE FUNCTION deny_security_event_mutation();

COMMIT;
