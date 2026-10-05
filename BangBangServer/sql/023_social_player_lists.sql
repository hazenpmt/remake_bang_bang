BEGIN;

CREATE TABLE IF NOT EXISTS guilds (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS guilds_name_lower_uq
    ON guilds (LOWER(name));

CREATE TABLE IF NOT EXISTS guild_members (
    guild_id BIGINT NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL UNIQUE REFERENCES accounts(id) ON DELETE CASCADE,
    role VARCHAR(16) NOT NULL DEFAULT 'member'
        CHECK (role IN ('leader', 'officer', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (guild_id, account_id)
);

CREATE INDEX IF NOT EXISTS guild_members_guild_joined_idx
    ON guild_members (guild_id, joined_at, account_id);

CREATE TABLE IF NOT EXISTS player_friendships (
    account_id_low BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    account_id_high BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    requested_by BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id_low, account_id_high),
    CHECK (account_id_low < account_id_high),
    CHECK (requested_by IN (account_id_low, account_id_high))
);

CREATE INDEX IF NOT EXISTS player_friendships_high_status_idx
    ON player_friendships (account_id_high, status, account_id_low);

CREATE TABLE IF NOT EXISTS game_room_invitations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES game_rooms(id) ON DELETE CASCADE,
    inviter_account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    invitee_account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    CHECK (inviter_account_id <> invitee_account_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS game_room_invitations_pending_uq
    ON game_room_invitations (room_id, invitee_account_id)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS game_room_invitations_invitee_status_idx
    ON game_room_invitations (invitee_account_id, status, expires_at);

COMMIT;
