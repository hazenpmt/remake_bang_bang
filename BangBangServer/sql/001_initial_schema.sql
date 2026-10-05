BEGIN;

CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(24) NOT NULL,
    password_hash TEXT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS accounts_username_lower_uq
    ON accounts (LOWER(username));

CREATE TABLE IF NOT EXISTS sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sessions_account_id_idx ON sessions(account_id);
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS player_profiles (
    account_id BIGINT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    display_name VARCHAR(10) NOT NULL,
    gender VARCHAR(8) NOT NULL CHECK (gender IN ('male', 'female')),
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    experience BIGINT NOT NULL DEFAULT 0 CHECK (experience >= 0),
    stamina INTEGER NOT NULL DEFAULT 100 CHECK (stamina >= 0),
    stamina_max INTEGER NOT NULL DEFAULT 100 CHECK (stamina_max > 0),
    avatar_key VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS player_profiles_display_name_lower_uq
    ON player_profiles (LOWER(display_name));

CREATE TABLE IF NOT EXISTS player_currencies (
    account_id BIGINT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    gold BIGINT NOT NULL DEFAULT 0 CHECK (gold >= 0),
    crystal BIGINT NOT NULL DEFAULT 0 CHECK (crystal >= 0),
    coupon BIGINT NOT NULL DEFAULT 0 CHECK (coupon >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tanks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tank_key VARCHAR(64) NOT NULL UNIQUE,
    display_name VARCHAR(64) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS player_tanks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    tank_id BIGINT NOT NULL REFERENCES tanks(id),
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    experience BIGINT NOT NULL DEFAULT 0 CHECK (experience >= 0),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (account_id, tank_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS player_tanks_one_primary_uq
    ON player_tanks(account_id)
    WHERE is_primary;

INSERT INTO tanks (tank_key, display_name)
VALUES ('starter_tank', 'Xe tăng khởi đầu')
ON CONFLICT (tank_key) DO NOTHING;

COMMIT;
