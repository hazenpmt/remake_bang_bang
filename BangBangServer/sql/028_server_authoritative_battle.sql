BEGIN;

ALTER TABLE game_matches
    DROP CONSTRAINT IF EXISTS game_matches_phase_check;

ALTER TABLE game_matches
    ADD CONSTRAINT game_matches_phase_check
    CHECK (
        phase IN (
            'confirming',
            'selecting',
            'loading',
            'transition',
            'active',
            'finished',
            'cancelled'
        )
    ),
    ADD COLUMN IF NOT EXISTS battle_protocol_version SMALLINT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS battle_revision BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS battle_simulated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS battle_ended_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS winner_team_no SMALLINT
        CHECK (winner_team_no IS NULL OR winner_team_no IN (0, 1, 2)),
    ADD COLUMN IF NOT EXISTS finish_reason VARCHAR(32),
    ADD COLUMN IF NOT EXISTS team_1_score INTEGER NOT NULL DEFAULT 0
        CHECK (team_1_score >= 0),
    ADD COLUMN IF NOT EXISTS team_2_score INTEGER NOT NULL DEFAULT 0
        CHECK (team_2_score >= 0);

CREATE TABLE IF NOT EXISTS game_match_battle_participants (
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    team_no SMALLINT NOT NULL CHECK (team_no IN (1, 2)),
    slot_no SMALLINT NOT NULL CHECK (slot_no BETWEEN 1 AND 5),
    account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    tank_key VARCHAR(64) NOT NULL,
    position_x NUMERIC(10, 3) NOT NULL,
    position_y NUMERIC(10, 3) NOT NULL,
    spawn_x NUMERIC(10, 3) NOT NULL,
    spawn_y NUMERIC(10, 3) NOT NULL,
    input_x NUMERIC(5, 4) NOT NULL DEFAULT 0,
    input_y NUMERIC(5, 4) NOT NULL DEFAULT 0,
    input_expires_at TIMESTAMPTZ,
    hit_points INTEGER NOT NULL CHECK (hit_points >= 0),
    maximum_hit_points INTEGER NOT NULL CHECK (maximum_hit_points > 0),
    shield_points INTEGER NOT NULL DEFAULT 0 CHECK (shield_points >= 0),
    maximum_shield_points INTEGER NOT NULL DEFAULT 0
        CHECK (maximum_shield_points >= 0),
    shield_recharge_at TIMESTAMPTZ,
    basic_attack_damage NUMERIC(12, 4) NOT NULL
        CHECK (basic_attack_damage >= 0),
    penetration NUMERIC(12, 4) NOT NULL CHECK (penetration >= 0),
    physical_armor NUMERIC(12, 4) NOT NULL CHECK (physical_armor >= 0),
    energy_shield NUMERIC(12, 4) NOT NULL CHECK (energy_shield >= 0),
    move_speed NUMERIC(12, 4) NOT NULL CHECK (move_speed >= 0),
    fire_rate NUMERIC(12, 4) NOT NULL CHECK (fire_rate > 0),
    attack_range NUMERIC(12, 4) NOT NULL CHECK (attack_range > 0),
    critical_chance_basis_points INTEGER NOT NULL
        CHECK (critical_chance_basis_points BETWEEN 0 AND 10000),
    critical_damage_basis_points INTEGER NOT NULL
        CHECK (critical_damage_basis_points >= 0),
    damage_type VARCHAR(16) NOT NULL
        CHECK (damage_type IN ('physical', 'energy')),
    basic_attack_ready_at TIMESTAMPTZ,
    skill_cooldown_ms JSONB NOT NULL DEFAULT '{}'::jsonb,
    skill_ready_at JSONB NOT NULL DEFAULT '{}'::jsonb,
    slow_until TIMESTAMPTZ,
    slow_factor NUMERIC(5, 4) NOT NULL DEFAULT 0
        CHECK (slow_factor BETWEEN 0 AND 1),
    airstrike_marker_until TIMESTAMPTZ,
    stun_until TIMESTAMPTZ,
    dead BOOLEAN NOT NULL DEFAULT FALSE,
    respawn_at TIMESTAMPTZ,
    invulnerable_until TIMESTAMPTZ,
    free_respawns_remaining SMALLINT NOT NULL DEFAULT 1
        CHECK (free_respawns_remaining BETWEEN 0 AND 1),
    kills INTEGER NOT NULL DEFAULT 0 CHECK (kills >= 0),
    deaths INTEGER NOT NULL DEFAULT 0 CHECK (deaths >= 0),
    assists INTEGER NOT NULL DEFAULT 0 CHECK (assists >= 0),
    damage_contributors JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_sequence BIGINT NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    last_command_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (match_id, team_no, slot_no),
    FOREIGN KEY (match_id, team_no, slot_no)
        REFERENCES game_match_participants(match_id, team_no, slot_no)
        ON DELETE CASCADE,
    CHECK (
        (is_bot AND account_id IS NULL)
        OR (NOT is_bot AND account_id IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS game_match_battle_participant_account_uq
    ON game_match_battle_participants(match_id, account_id)
    WHERE account_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS game_match_battle_effects (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    owner_team_no SMALLINT NOT NULL CHECK (owner_team_no IN (1, 2)),
    owner_slot_no SMALLINT NOT NULL CHECK (owner_slot_no BETWEEN 1 AND 5),
    effect_type VARCHAR(24) NOT NULL
        CHECK (effect_type IN ('airstrike', 'beam')),
    origin_x NUMERIC(10, 3) NOT NULL,
    origin_y NUMERIC(10, 3) NOT NULL,
    direction_x NUMERIC(5, 4) NOT NULL DEFAULT 1,
    direction_y NUMERIC(5, 4) NOT NULL DEFAULT 0,
    radius NUMERIC(10, 3) NOT NULL DEFAULT 0 CHECK (radius >= 0),
    range_value NUMERIC(10, 3) NOT NULL DEFAULT 0 CHECK (range_value >= 0),
    half_width NUMERIC(10, 3) NOT NULL DEFAULT 0 CHECK (half_width >= 0),
    damage_ratio NUMERIC(8, 4) NOT NULL CHECK (damage_ratio >= 0),
    next_tick_at TIMESTAMPTZ NOT NULL,
    tick_interval_ms INTEGER NOT NULL CHECK (tick_interval_ms BETWEEN 50 AND 5000),
    ends_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (match_id, owner_team_no, owner_slot_no)
        REFERENCES game_match_battle_participants(match_id, team_no, slot_no)
        ON DELETE CASCADE,
    CHECK (ends_at >= next_tick_at)
);

CREATE INDEX IF NOT EXISTS game_match_battle_effects_due_idx
    ON game_match_battle_effects(match_id, next_tick_at, id);

CREATE TABLE IF NOT EXISTS game_match_battle_commands (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    sequence_no BIGINT NOT NULL CHECK (sequence_no > 0),
    command_type VARCHAR(24) NOT NULL,
    payload JSONB NOT NULL,
    payload_hash CHAR(64) NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (match_id, account_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS game_match_battle_commands_account_idx
    ON game_match_battle_commands(account_id, match_id, sequence_no DESC);

CREATE TABLE IF NOT EXISTS game_match_battle_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL CHECK (revision >= 0),
    event_type VARCHAR(32) NOT NULL,
    actor_team_no SMALLINT CHECK (actor_team_no IN (1, 2)),
    actor_slot_no SMALLINT CHECK (actor_slot_no BETWEEN 1 AND 5),
    target_team_no SMALLINT CHECK (target_team_no IN (1, 2)),
    target_slot_no SMALLINT CHECK (target_slot_no BETWEEN 1 AND 5),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS game_match_battle_events_match_revision_idx
    ON game_match_battle_events(match_id, revision, id);

COMMIT;
