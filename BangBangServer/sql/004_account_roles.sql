BEGIN;

ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS role VARCHAR(16) NOT NULL DEFAULT 'player';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conname = 'accounts_role_check'
    ) THEN
        ALTER TABLE accounts
            ADD CONSTRAINT accounts_role_check
            CHECK (role IN ('player', 'admin'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conname = 'accounts_status_check'
    ) THEN
        ALTER TABLE accounts
            ADD CONSTRAINT accounts_status_check
            CHECK (status IN ('active', 'suspended', 'banned'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS accounts_role_idx ON accounts(role);

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    target_account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    action VARCHAR(64) NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS admin_audit_log_created_at_idx
    ON admin_audit_log(created_at DESC);

COMMIT;
