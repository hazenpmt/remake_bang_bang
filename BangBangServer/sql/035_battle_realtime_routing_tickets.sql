BEGIN;

CREATE TABLE IF NOT EXISTS battle_worker_nodes (
    worker_id VARCHAR(96) PRIMARY KEY,
    node_id VARCHAR(96) NOT NULL,
    public_realtime_url TEXT,
    lease_until TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (
        public_realtime_url IS NULL
        OR public_realtime_url ~ '^wss?://'
    )
);

CREATE INDEX IF NOT EXISTS battle_worker_nodes_lease_idx
    ON battle_worker_nodes(lease_until, worker_id);

CREATE TABLE IF NOT EXISTS battle_realtime_tickets (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    token_hash CHAR(64) NOT NULL UNIQUE,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    session_id BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    route_worker_id VARCHAR(96) NOT NULL,
    worker_epoch BIGINT NOT NULL CHECK (worker_epoch > 0),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (expires_at > created_at),
    CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE INDEX IF NOT EXISTS battle_realtime_tickets_expiry_idx
    ON battle_realtime_tickets(expires_at, id);

CREATE INDEX IF NOT EXISTS battle_realtime_tickets_session_idx
    ON battle_realtime_tickets(session_id, expires_at DESC);

COMMIT;
