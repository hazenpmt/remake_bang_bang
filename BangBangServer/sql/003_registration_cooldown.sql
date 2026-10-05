BEGIN;

CREATE TABLE IF NOT EXISTS account_registrations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    ip_hash CHAR(64) NOT NULL,
    device_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS account_registrations_ip_time_idx
    ON account_registrations(ip_hash, created_at DESC);
CREATE INDEX IF NOT EXISTS account_registrations_device_time_idx
    ON account_registrations(device_hash, created_at DESC);

COMMIT;
