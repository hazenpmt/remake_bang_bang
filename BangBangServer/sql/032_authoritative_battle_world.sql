BEGIN;

ALTER TABLE game_matches
    ALTER COLUMN battle_protocol_version SET DEFAULT 2;

UPDATE game_matches
   SET battle_protocol_version = 2
 WHERE battle_protocol_version < 2
   AND phase IN ('active', 'finished');

CREATE TABLE IF NOT EXISTS game_match_battle_world_entities (
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    entity_key VARCHAR(64) NOT NULL,
    entity_type VARCHAR(16) NOT NULL
        CHECK (entity_type IN ('building', 'chief', 'footpoint')),
    template_id INTEGER,
    spawner_building_id INTEGER,
    team_no SMALLINT NOT NULL CHECK (team_no BETWEEN 0 AND 2),
    position_x NUMERIC(10, 3) NOT NULL,
    position_y NUMERIC(10, 3) NOT NULL,
    spawn_x NUMERIC(10, 3) NOT NULL,
    spawn_y NUMERIC(10, 3) NOT NULL,
    patrol_left_x NUMERIC(10, 3),
    patrol_right_x NUMERIC(10, 3),
    initial_direction SMALLINT NOT NULL DEFAULT 1
        CHECK (initial_direction IN (-1, 1)),
    move_direction SMALLINT NOT NULL DEFAULT 1
        CHECK (move_direction IN (-1, 1)),
    hit_points INTEGER NOT NULL CHECK (hit_points >= 0),
    maximum_hit_points INTEGER NOT NULL CHECK (maximum_hit_points > 0),
    basic_attack_damage NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (basic_attack_damage >= 0),
    penetration NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (penetration >= 0),
    physical_armor NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (physical_armor >= 0),
    energy_shield NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (energy_shield >= 0),
    move_speed NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (move_speed >= 0),
    attack_range NUMERIC(12, 4) NOT NULL DEFAULT 0
        CHECK (attack_range >= 0),
    hit_radius NUMERIC(10, 3) NOT NULL DEFAULT 36
        CHECK (hit_radius > 0),
    damage_type VARCHAR(16) NOT NULL DEFAULT 'physical'
        CHECK (damage_type IN ('physical', 'energy')),
    attack_interval_ms INTEGER NOT NULL DEFAULT 1000
        CHECK (attack_interval_ms > 0),
    attack_ready_at TIMESTAMPTZ,
    burst_shots SMALLINT NOT NULL DEFAULT 1 CHECK (burst_shots > 0),
    burst_remaining SMALLINT NOT NULL DEFAULT 0 CHECK (burst_remaining >= 0),
    burst_break_ms INTEGER NOT NULL DEFAULT 0 CHECK (burst_break_ms >= 0),
    burst_ready_at TIMESTAMPTZ,
    respawn_ms INTEGER NOT NULL DEFAULT 0 CHECK (respawn_ms >= 0),
    can_attack BOOLEAN NOT NULL DEFAULT FALSE,
    is_structure BOOLEAN NOT NULL DEFAULT FALSE,
    activated BOOLEAN NOT NULL DEFAULT TRUE,
    active_at TIMESTAMPTZ,
    dead BOOLEAN NOT NULL DEFAULT FALSE,
    respawn_at TIMESTAMPTZ,
    slow_until TIMESTAMPTZ,
    slow_factor NUMERIC(5, 4) NOT NULL DEFAULT 0
        CHECK (slow_factor BETWEEN 0 AND 1),
    airstrike_marker_until TIMESTAMPTZ,
    stun_until TIMESTAMPTZ,
    hits_to_destroy INTEGER NOT NULL DEFAULT 0 CHECK (hits_to_destroy >= 0),
    hit_count INTEGER NOT NULL DEFAULT 0 CHECK (hit_count >= 0),
    collision_rectangles JSONB NOT NULL DEFAULT '[]'::jsonb,
    attack_serial BIGINT NOT NULL DEFAULT 0 CHECK (attack_serial >= 0),
    last_target_key VARCHAR(64),
    wander_target_x NUMERIC(10, 3),
    wander_target_y NUMERIC(10, 3),
    wander_ready_at TIMESTAMPTZ,
    wander_sequence BIGINT NOT NULL DEFAULT 0 CHECK (wander_sequence >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (match_id, entity_key),
    CHECK (
        (entity_type = 'building' AND template_id IS NOT NULL)
        OR (entity_type <> 'building' AND template_id IS NULL)
    ),
    CHECK (
        (entity_type = 'footpoint' AND spawner_building_id IS NOT NULL)
        OR (entity_type <> 'footpoint' AND spawner_building_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS game_match_battle_world_active_idx
    ON game_match_battle_world_entities(match_id, entity_type, dead, activated);

CREATE TABLE IF NOT EXISTS game_match_battle_world_projectiles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES game_matches(id) ON DELETE CASCADE,
    source_entity_key VARCHAR(64) NOT NULL,
    source_team_no SMALLINT NOT NULL CHECK (source_team_no BETWEEN 0 AND 2),
    projectile_type VARCHAR(16) NOT NULL
        CHECK (projectile_type IN ('cannon', 'missile', 'chief')),
    position_x NUMERIC(10, 3) NOT NULL,
    position_y NUMERIC(10, 3) NOT NULL,
    direction_x NUMERIC(7, 6) NOT NULL,
    direction_y NUMERIC(7, 6) NOT NULL,
    speed NUMERIC(12, 4) NOT NULL CHECK (speed > 0),
    remaining_distance NUMERIC(12, 4) NOT NULL
        CHECK (remaining_distance >= 0),
    damage NUMERIC(12, 4) NOT NULL CHECK (damage >= 0),
    penetration NUMERIC(12, 4) NOT NULL DEFAULT 0,
    damage_type VARCHAR(16) NOT NULL DEFAULT 'physical'
        CHECK (damage_type IN ('physical', 'energy')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (match_id, source_entity_key)
        REFERENCES game_match_battle_world_entities(match_id, entity_key)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS game_match_battle_world_projectiles_match_idx
    ON game_match_battle_world_projectiles(match_id, id);

COMMIT;
