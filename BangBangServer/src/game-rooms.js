import { pool, withTransaction } from "./db.js";
import { summarizeMatchParticipants } from "./match-flow-policy.js";
import { compactRoomMembers } from "./room-member-order.js";

const ROOM_LOCK_KEY = 726554291;
const VALID_TABS = new Set(["event", "solo", "rank", "guild", "test"]);
const VALID_MODES = new Set(["free"]);
const ROOM_NAME_MAX_LENGTH = 40;
const MATCHMAKING_ESTIMATED_SECONDS = 30;
// The TEST room is an isolated bot sandbox. It should enter the match flow
// quickly so an operator can validate the battle without waiting for the
// production matchmaking window.
const TEST_MATCHMAKING_ESTIMATED_SECONDS = 2;
const TEST_ENEMY_BOT_COUNT = 5;
const MATCH_CONFIRM_SECONDS = 30;
const TANK_SELECT_INTRO_SECONDS = 3;
const TANK_PREPARATION_SECONDS = 5;
const BOT_CONFIRM_STEP_SECONDS = 0.45;
const TRANSITION_SECONDS = 5;

export class GameRoomError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function normalizedTab(value) {
  const tab = String(value ?? "").trim().toLowerCase();
  if (!VALID_TABS.has(tab)) {
    throw new GameRoomError(400, "INVALID_ROOM_TAB", "Loại phòng không hợp lệ.");
  }
  return tab;
}

function normalizedRoomCode(value) {
  const roomCode = String(value ?? "").trim();
  if (!/^\d{1,18}$/.test(roomCode)) {
    throw new GameRoomError(400, "INVALID_ROOM_ID", "Mã phòng không hợp lệ.");
  }
  return roomCode;
}

function normalizedMapKey(value) {
  const mapKey = String(value ?? "").trim().toLowerCase();
  if (!/^[a-z0-9_]{1,64}$/.test(mapKey)) {
    throw new GameRoomError(400, "INVALID_MAP", "Bản đồ không hợp lệ.");
  }
  return mapKey;
}

async function lockRooms(client) {
  await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [ROOM_LOCK_KEY]);
}

async function cleanupStaleRooms(client) {
  await client.query(
    `DELETE FROM game_room_members member
      WHERE NOT EXISTS (
        SELECT 1
          FROM online_presence presence
         WHERE presence.account_id = member.account_id
           AND presence.lease_expires_at > NOW()
      )`,
  );
  await client.query(
    `DELETE FROM game_rooms room
      WHERE NOT room.is_test
        AND NOT EXISTS (
          SELECT 1 FROM game_room_members member WHERE member.room_id = room.id
      )`,
  );
  await client.query(
    `UPDATE game_room_matchmaking matchmaking
        SET state = 'searching',
            matched_room_id = NULL,
            matched_at = NULL,
            started_at = NOW(),
            updated_at = NOW()
      WHERE matchmaking.state = 'matched'
        AND matchmaking.match_id IS NULL
        AND EXISTS (
          SELECT 1
            FROM game_rooms room
           WHERE room.id = matchmaking.room_id
             AND room.status = 'matching'
        )`,
  );
  await client.query(
    `DELETE FROM game_room_matchmaking matchmaking
      USING game_rooms room
      WHERE matchmaking.room_id = room.id
        AND room.is_test
        AND NOT EXISTS (
          SELECT 1 FROM game_room_members member WHERE member.room_id = room.id
        )`,
  );
  await client.query(
    `UPDATE game_rooms room
        SET status = 'waiting', updated_at = NOW()
      WHERE room.is_test
        AND room.status <> 'waiting'
        AND NOT EXISTS (
          SELECT 1 FROM game_room_members member WHERE member.room_id = room.id
        )`,
  );
}

async function roomByCodeForUpdate(client, roomCode) {
  const result = await client.query(
    `SELECT *
       FROM game_rooms
      WHERE room_code = $1::bigint
      FOR UPDATE`,
    [roomCode],
  );
  if (result.rowCount !== 1) {
    throw new GameRoomError(404, "ROOM_NOT_FOUND", "Phòng không còn tồn tại.");
  }
  return result.rows[0];
}

async function resolveMatchMap(client, requestedMapKey) {
  if (requestedMapKey !== "random") {
    return requestedMapKey;
  }
  const result = await client.query(
    `SELECT map_key
       FROM game_maps
      WHERE enabled
        AND map_key <> 'random'
      ORDER BY RANDOM()
      LIMIT 1`,
  );
  return result.rows[0]?.map_key ?? "random";
}

async function insertRoomParticipants(client, matchId, roomId, teamNo) {
  await client.query(
    `INSERT INTO game_match_participants(
       match_id,
       team_no,
       slot_no,
       account_id,
       display_name,
       gender,
       level,
       avatar_key,
       tank_key,
       tank_name,
       tank_preview_asset_key,
       tank_level,
       equipped_skin_key,
       equipped_skin_name,
       equipped_skin_preview_asset_key
     )
     SELECT
       $1,
       $3,
       ROW_NUMBER() OVER (ORDER BY member.join_order)::smallint,
       member.account_id,
       profile.display_name,
       profile.gender,
       profile.level,
       profile.avatar_key,
       tank.tank_key,
       tank.display_name,
       tank.preview_asset_key,
       COALESCE(player_tank.level, 1),
       equipped_skin.skin_key,
       equipped_skin.display_name,
       equipped_skin.preview_asset_key
     FROM game_room_members member
     JOIN player_profiles profile ON profile.account_id = member.account_id
     LEFT JOIN player_tanks player_tank
            ON player_tank.account_id = member.account_id
           AND player_tank.is_primary
     LEFT JOIN tanks tank ON tank.id = player_tank.tank_id
     LEFT JOIN tank_skins equipped_skin
            ON equipped_skin.id = player_tank.equipped_skin_id
     WHERE member.room_id = $2
     ORDER BY member.join_order
     LIMIT 5`,
    [matchId, roomId, teamNo],
  );
}

async function insertTestBots(client, matchId) {
  await client.query(
    `INSERT INTO game_match_participants(
       match_id,
       team_no,
       slot_no,
       is_bot,
       display_name,
       gender,
       level,
       avatar_key,
       bot_confirm_at
     )
     SELECT
       $1,
       2,
       bot.slot_no::smallint,
       TRUE,
       'BOT ' || bot.slot_no,
       CASE WHEN bot.slot_no % 2 = 0 THEN 'female' ELSE 'male' END,
       1,
       CASE
         WHEN bot.slot_no % 2 = 0 THEN 'default_female'
         ELSE 'default_male'
       END,
       NOW() + ($2 * bot.slot_no) * INTERVAL '1 second'
     FROM GENERATE_SERIES(1, $3) AS bot(slot_no)`,
    [matchId, BOT_CONFIRM_STEP_SECONDS, TEST_ENEMY_BOT_COUNT],
  );
}

async function createMatch(client, room, opponentRoomId = null) {
  const existingResult = await client.query(
    `SELECT match_id
       FROM game_room_matchmaking
      WHERE room_id = $1`,
    [room.id],
  );
  if (existingResult.rows[0]?.match_id) {
    return existingResult.rows[0].match_id;
  }

  const mapKey = await resolveMatchMap(client, room.map_key);
  const matchResult = await client.query(
    `INSERT INTO game_matches(
       team_a_room_id,
       team_b_room_id,
       is_test,
       map_key,
       confirmation_deadline
     )
     VALUES (
       $1,
       $2,
       $3,
       $4,
       NOW() + $5 * INTERVAL '1 second'
     )
     RETURNING id`,
    [
      room.id,
      opponentRoomId,
      room.is_test,
      mapKey,
      MATCH_CONFIRM_SECONDS,
    ],
  );
  const matchId = matchResult.rows[0].id;
  await insertRoomParticipants(client, matchId, room.id, 1);
  if (room.is_test) {
    await insertTestBots(client, matchId);
  } else {
    await insertRoomParticipants(client, matchId, opponentRoomId, 2);
  }

  const roomIds = opponentRoomId
    ? [room.id, opponentRoomId]
    : [room.id];
  await client.query(
    `UPDATE game_room_matchmaking
        SET state = 'matched',
            match_id = $1,
            matched_room_id = CASE
              WHEN $2::bigint IS NULL THEN NULL
              WHEN room_id = $3 THEN $2
              ELSE $3
            END,
            matched_at = NOW(),
            updated_at = NOW()
      WHERE room_id = ANY($4::bigint[])`,
    [matchId, opponentRoomId, room.id, roomIds],
  );
  return matchId;
}

async function assignBotTanks(client, matchId) {
  const tanksResult = await client.query(
    `SELECT tank.tank_key,
            tank.display_name,
            tank.preview_asset_key,
            default_skin.skin_key,
            default_skin.display_name AS skin_name,
            default_skin.preview_asset_key AS skin_preview_asset_key
       FROM tanks tank
       LEFT JOIN LATERAL (
         SELECT skin_key, display_name, preview_asset_key
           FROM tank_skins
          WHERE tank_id = tank.id
            AND enabled
          ORDER BY is_default DESC, id
          LIMIT 1
      ) default_skin ON TRUE
      WHERE tank.enabled
        AND tank.battle_kit_key IS NOT NULL
      ORDER BY RANDOM()`,
  );
  if (tanksResult.rowCount === 0) {
    return;
  }
  const botsResult = await client.query(
    `SELECT team_no, slot_no
       FROM game_match_participants
      WHERE match_id = $1 AND is_bot
      ORDER BY team_no, slot_no`,
    [matchId],
  );
  for (let index = 0; index < botsResult.rows.length; index += 1) {
    const bot = botsResult.rows[index];
    const tank = tanksResult.rows[index % tanksResult.rows.length];
    await client.query(
      `UPDATE game_match_participants
          SET tank_key = $1,
              tank_name = $2,
              tank_preview_asset_key = $3,
              equipped_skin_key = $4,
              equipped_skin_name = $5,
              equipped_skin_preview_asset_key = $6,
              deployed = TRUE,
              deployed_at = NOW(),
              updated_at = NOW()
        WHERE match_id = $7
          AND team_no = $8
          AND slot_no = $9`,
      [
        tank.tank_key,
        tank.display_name,
        tank.preview_asset_key,
        tank.skin_key,
        tank.skin_name,
        tank.skin_preview_asset_key,
        matchId,
        bot.team_no,
        bot.slot_no,
      ],
    );
  }
}

async function resetMatchRooms(client, match) {
  const roomIds = [match.team_a_room_id, match.team_b_room_id].filter(Boolean);
  await client.query(
    `UPDATE game_matches
        SET phase = 'cancelled',
            cancelled_at = NOW(),
            updated_at = NOW()
      WHERE id = $1`,
    [match.id],
  );
  await client.query(
    `UPDATE game_rooms
        SET status = 'matching', updated_at = NOW()
      WHERE id = ANY($1::bigint[])`,
    [roomIds],
  );
  await client.query(
    `UPDATE game_room_matchmaking
        SET state = 'searching',
            match_id = NULL,
            matched_room_id = NULL,
            matched_at = NULL,
            started_at = NOW(),
            updated_at = NOW()
      WHERE room_id = ANY($1::bigint[])`,
    [roomIds],
  );
}

async function advanceMatchFlow(client, matchId) {
  if (!matchId) {
    return;
  }
  const matchResult = await client.query(
    `SELECT *
       FROM game_matches
      WHERE id = $1
      FOR UPDATE`,
    [matchId],
  );
  if (matchResult.rowCount !== 1) {
    return;
  }
  const match = matchResult.rows[0];
  if (match.phase === "confirming") {
    await client.query(
      `UPDATE game_match_participants
          SET confirmed = TRUE,
              confirmed_at = COALESCE(confirmed_at, NOW()),
              updated_at = NOW()
        WHERE match_id = $1
          AND is_bot
          AND NOT confirmed
          AND bot_confirm_at <= NOW()`,
      [match.id],
    );
    const confirmationResult = await client.query(
      `SELECT COUNT(*)::int AS required,
              COUNT(*) FILTER (WHERE confirmed)::int AS completed,
              NOW() >= $2::timestamptz AS expired
         FROM game_match_participants
        WHERE match_id = $1`,
      [match.id, match.confirmation_deadline],
    );
    const confirmation = confirmationResult.rows[0];
    if (confirmation.completed >= confirmation.required) {
      await client.query(
        `UPDATE game_matches
            SET phase = 'selecting',
                selection_intro_until =
                  NOW() + $2 * INTERVAL '1 second',
                updated_at = NOW()
          WHERE id = $1`,
        [match.id, TANK_SELECT_INTRO_SECONDS],
      );
      await assignBotTanks(client, match.id);
    } else if (confirmation.expired) {
      await resetMatchRooms(client, match);
    }
    return;
  }

  if (match.phase === "selecting") {
    const deployResult = await client.query(
      `SELECT COUNT(*)::int AS required,
              COUNT(*) FILTER (WHERE deployed)::int AS completed,
              COALESCE(
                NOW() >= (
                  MAX(deployed_at)
                  + $2 * INTERVAL '1 second'
                ),
                FALSE
              ) AS preparation_finished
         FROM game_match_participants
        WHERE match_id = $1`,
      [match.id, TANK_PREPARATION_SECONDS],
    );
    if (
      deployResult.rows[0].completed >= deployResult.rows[0].required
      && deployResult.rows[0].preparation_finished
    ) {
      await client.query(
        `UPDATE game_matches
            SET phase = 'loading',
                loading_started_at = NOW(),
                updated_at = NOW()
          WHERE id = $1`,
        [match.id],
      );
      await client.query(
        `UPDATE game_match_participants
            SET load_progress = 100,
                load_ready = TRUE,
                updated_at = NOW()
          WHERE match_id = $1 AND is_bot`,
        [match.id],
      );
    }
    return;
  }

  if (match.phase === "loading") {
    const loadingResult = await client.query(
      `SELECT COUNT(*)::int AS required,
              COUNT(*) FILTER (
                WHERE load_ready AND load_progress = 100
              )::int AS completed
         FROM game_match_participants
        WHERE match_id = $1`,
      [match.id],
    );
    if (loadingResult.rows[0].completed >= loadingResult.rows[0].required) {
      await client.query(
        `UPDATE game_matches
            SET phase = 'transition',
                transition_started_at = NOW(),
                updated_at = NOW()
          WHERE id = $1`,
        [match.id],
      );
    }
    return;
  }

  if (match.phase === "transition") {
    const transitionResult = await client.query(
      `SELECT NOW() >= (
         $1::timestamptz + $2 * INTERVAL '1 second'
       ) AS completed`,
      [match.transition_started_at, TRANSITION_SECONDS],
    );
    if (transitionResult.rows[0].completed) {
      const roomIds = [match.team_a_room_id, match.team_b_room_id].filter(Boolean);
      await client.query(
        `UPDATE game_matches
            SET phase = 'active',
                activated_at = NOW(),
                updated_at = NOW()
          WHERE id = $1`,
        [match.id],
      );
      await client.query(
        `UPDATE game_rooms
            SET status = 'running', updated_at = NOW()
          WHERE id = ANY($1::bigint[])`,
        [roomIds],
      );
    }
  }
}

async function matchPayload(client, matchId, viewerAccountId = null) {
  await advanceMatchFlow(client, matchId);
  const matchResult = await client.query(
    `SELECT match.id::text,
            match.phase,
            match.is_test,
            match.map_key,
            COALESCE(game_map.display_name, match.map_key) AS map_name,
            COALESCE(game_map.thumbnail_asset_path, '')
                AS map_thumbnail_asset_path,
            match.confirmation_deadline,
            match.selection_intro_until,
            match.loading_started_at,
            match.transition_started_at,
            match.activated_at,
            GREATEST(
              0,
              CEIL(EXTRACT(EPOCH FROM (
                match.confirmation_deadline - NOW()
              )))
            )::int AS confirmation_seconds_remaining,
            GREATEST(
              0,
              CEIL(EXTRACT(EPOCH FROM (
                COALESCE(match.selection_intro_until, NOW()) - NOW()
              )))
            )::int AS selection_intro_seconds_remaining,
            CASE
              WHEN match.phase = 'selecting'
               AND deploy_summary.required_count > 0
               AND deploy_summary.deployed_count
                   >= deploy_summary.required_count
              THEN GREATEST(
                0,
                CEIL(EXTRACT(EPOCH FROM (
                  deploy_summary.last_deployed_at
                  + $2 * INTERVAL '1 second'
                  - NOW()
                )))
              )::int
              ELSE 0
            END AS preparation_seconds_remaining
       FROM game_matches match
       LEFT JOIN game_maps game_map ON game_map.map_key = match.map_key
       LEFT JOIN LATERAL (
         SELECT COUNT(*)::int AS required_count,
                COUNT(*) FILTER (WHERE deployed)::int AS deployed_count,
                MAX(deployed_at) AS last_deployed_at
           FROM game_match_participants participant
          WHERE participant.match_id = match.id
       ) deploy_summary ON TRUE
      WHERE match.id = $1`,
    [matchId, TANK_PREPARATION_SECONDS],
  );
  if (matchResult.rowCount !== 1) {
    return null;
  }
  const participantResult = await client.query(
    `SELECT team_no,
            slot_no,
            COALESCE(account_id::text, '') AS account_id,
            is_bot,
            display_name,
            gender,
            level,
            avatar_key,
            tank_key,
            tank_name,
            tank_preview_asset_key,
            tank_level,
            COALESCE(equipped_skin_key, '') AS equipped_skin_key,
            COALESCE(equipped_skin_name, '') AS equipped_skin_name,
            COALESCE(equipped_skin_preview_asset_key, '')
                AS equipped_skin_preview_asset_key,
            COALESCE(skin_frame.frame_tier, '') AS skin_frame_tier,
            COALESCE(skin_bonus.revive_speed_percent, 0)::int
                AS revive_speed_percent,
            COALESCE(skin_bonus.revive_duration_seconds, 0)::int
                AS revive_duration_seconds,
            confirmed,
            deployed,
            load_progress,
            load_ready,
            participant.updated_at AS battle_joined_at,
            (
              participant.is_bot
              OR (
                EXISTS (
                  SELECT 1
                    FROM game_room_members live_member
                    JOIN game_room_matchmaking live_matchmaking
                      ON live_matchmaking.room_id = live_member.room_id
                   WHERE live_matchmaking.match_id = participant.match_id
                     AND live_member.account_id = participant.account_id
                )
                AND EXISTS (
                  SELECT 1
                    FROM online_presence live_presence
                   WHERE live_presence.account_id = participant.account_id
                     AND live_presence.lease_expires_at > NOW()
                )
              )
            ) AS connected
       FROM game_match_participants participant
       LEFT JOIN LATERAL (
         SELECT COALESCE(
                  ARRAY_AGG(DISTINCT UPPER(skin.quality_key))
                    FILTER (WHERE skin.quality_key IS NOT NULL),
                  ARRAY[]::text[]
                ) AS qualities
           FROM player_tank_skins owned_skin
           JOIN tank_skins skin ON skin.id = owned_skin.tank_skin_id
           JOIN tanks tank ON tank.id = skin.tank_id
          WHERE owned_skin.account_id = participant.account_id
            AND tank.tank_key = participant.tank_key
            AND skin.enabled
       ) owned_skin_summary ON NOT participant.is_bot
       LEFT JOIN LATERAL (
         SELECT rule.frame_tier
           FROM tank_skin_collection_rules rule
          WHERE rule.enabled
            AND COALESCE(rule.frame_tier, '') <> ''
            AND (
              (
                rule.requirement_type = 'quality'
                AND UPPER(rule.required_quality)
                    = ANY(owned_skin_summary.qualities)
              )
              OR
              (
                rule.requirement_type = 'distinct_quality_count'
                AND CARDINALITY(owned_skin_summary.qualities)
                    >= rule.required_distinct_quality_count
                AND (
                  NOT rule.requires_sss
                  OR 'SSS' = ANY(owned_skin_summary.qualities)
                )
              )
            )
          ORDER BY rule.sort_order DESC, rule.id DESC
          LIMIT 1
       ) skin_frame ON TRUE
       LEFT JOIN LATERAL (
         SELECT COALESCE(SUM(rule.revive_speed_percent), 0)
                    AS revive_speed_percent,
                COALESCE(MAX(rule.revive_duration_seconds), 0)
                    AS revive_duration_seconds
           FROM tank_skin_collection_rules rule
          WHERE rule.enabled
            AND (
              (
                rule.requirement_type = 'quality'
                AND UPPER(rule.required_quality)
                    = ANY(owned_skin_summary.qualities)
              )
              OR
              (
                rule.requirement_type = 'distinct_quality_count'
                AND CARDINALITY(owned_skin_summary.qualities)
                    >= rule.required_distinct_quality_count
                AND (
                  NOT rule.requires_sss
                  OR 'SSS' = ANY(owned_skin_summary.qualities)
                )
              )
            )
       ) skin_bonus ON TRUE
      WHERE participant.match_id = $1
      ORDER BY participant.team_no, participant.slot_no`,
    [matchId],
  );
  const participants = participantResult.rows;
  const summary = summarizeMatchParticipants(participants);
  const viewer = viewerAccountId == null
    ? null
    : participants.find(
      (participant) => String(participant.account_id) === String(viewerAccountId),
    );
  return {
    ...matchResult.rows[0],
    viewer_team_no: viewer?.team_no ?? null,
    required_count: summary.requiredCount,
    confirmed_count: summary.confirmedCount,
    deployed_count: summary.deployedCount,
    loaded_count: summary.loadedCount,
    participants,
  };
}

async function advanceMatchmaking(client, roomId) {
  const roomResult = await client.query(
    `SELECT room.*,
            matchmaking.started_at,
            matchmaking.estimated_seconds,
            matchmaking.state AS matchmaking_state,
            matchmaking.match_id
       FROM game_rooms room
       LEFT JOIN game_room_matchmaking matchmaking
              ON matchmaking.room_id = room.id
      WHERE room.id = $1
      FOR UPDATE OF room`,
    [roomId],
  );
  if (
    roomResult.rowCount !== 1
    || roomResult.rows[0].status !== "matching"
  ) {
    return;
  }
  const room = roomResult.rows[0];
  if (room.matchmaking_state === "matched" && room.match_id) {
    await advanceMatchFlow(client, room.match_id);
    return;
  }
  if (room.matchmaking_state && room.matchmaking_state !== "searching") {
    return;
  }
  if (!room.started_at) {
    await client.query(
      `INSERT INTO game_room_matchmaking(
         room_id,
         estimated_seconds,
         enemy_bot_count
       )
       VALUES ($1, $2, $3)
       ON CONFLICT (room_id) DO NOTHING`,
      [
        room.id,
        room.is_test
          ? TEST_MATCHMAKING_ESTIMATED_SECONDS
          : MATCHMAKING_ESTIMATED_SECONDS,
        room.is_test ? TEST_ENEMY_BOT_COUNT : 0,
      ],
    );
    return;
  }

  if (room.is_test) {
    const elapsedResult = await client.query(
      `SELECT FLOOR(
                EXTRACT(EPOCH FROM (NOW() - $1::timestamptz))
              )::int
              AS elapsed_seconds`,
      [room.started_at],
    );
    if (
      elapsedResult.rows[0].elapsed_seconds
      < room.estimated_seconds
    ) {
      return;
    }
    await createMatch(client, room);
    return;
  }

  const memberCountResult = await client.query(
    `SELECT COUNT(*)::int AS count
       FROM game_room_members
      WHERE room_id = $1`,
    [room.id],
  );
  if (memberCountResult.rows[0].count < room.max_players) {
    return;
  }
  const opponentResult = await client.query(
    `SELECT opponent.id
       FROM game_rooms opponent
       JOIN game_room_matchmaking opponent_matchmaking
         ON opponent_matchmaking.room_id = opponent.id
        AND opponent_matchmaking.state = 'searching'
      WHERE opponent.id <> $1
        AND opponent.status = 'matching'
        AND NOT opponent.is_test
        AND opponent.tab_key = $2
        AND opponent.mode_key = $3
        AND (
          opponent.map_key = $4
          OR opponent.map_key = 'random'
          OR $4 = 'random'
        )
        AND (
          SELECT COUNT(*)
            FROM game_room_members opponent_member
           WHERE opponent_member.room_id = opponent.id
        ) >= opponent.max_players
      ORDER BY opponent_matchmaking.started_at, opponent.id
      LIMIT 1
      FOR UPDATE OF opponent SKIP LOCKED`,
    [room.id, room.tab_key, room.mode_key, room.map_key],
  );
  if (opponentResult.rowCount !== 1) {
    return;
  }
  const opponentRoomId = opponentResult.rows[0].id;
  await createMatch(client, room, opponentRoomId);
}

async function roomPayload(client, roomId, viewerAccountId = null) {
  await advanceMatchmaking(client, roomId);
  const roomResult = await client.query(
    `SELECT room.id,
            room.room_code::text,
            room.tab_key,
            room.room_name,
            room.mode_key,
            room.map_key,
            COALESCE(game_map.display_name, room.map_key) AS map_name,
            COALESCE(game_map.thumbnail_asset_path, '')
                AS map_thumbnail_asset_path,
            room.max_players,
            room.status,
            room.is_test,
            room.created_at
       FROM game_rooms room
       LEFT JOIN game_maps game_map
              ON game_map.map_key = room.map_key
      WHERE room.id = $1`,
    [roomId],
  );
  if (roomResult.rowCount !== 1) {
    throw new GameRoomError(404, "ROOM_NOT_FOUND", "Phòng không còn tồn tại.");
  }

  const memberResult = await client.query(
    `SELECT member.account_id,
            member.join_order::text,
            profile.display_name,
            profile.gender,
            profile.level,
            profile.avatar_key,
            COALESCE(tank.tank_key, '') AS tank_key,
            COALESCE(tank.display_name, 'Tank') AS tank_name,
            COALESCE(tank.preview_asset_key, '') AS tank_preview_asset_key,
            player_tank.level AS tank_level,
            COALESCE(equipped_skin.skin_key, '') AS equipped_skin_key,
            COALESCE(equipped_skin.display_name, '') AS equipped_skin_name,
            COALESCE(equipped_skin.preview_asset_key, '')
                AS equipped_skin_preview_asset_key
       FROM game_room_members member
       JOIN player_profiles profile ON profile.account_id = member.account_id
       LEFT JOIN player_tanks player_tank
              ON player_tank.account_id = member.account_id
             AND player_tank.is_primary
       LEFT JOIN tanks tank ON tank.id = player_tank.tank_id
       LEFT JOIN tank_skins equipped_skin
              ON equipped_skin.id = player_tank.equipped_skin_id
      WHERE member.room_id = $1
      ORDER BY member.join_order`,
    [roomId],
  );
  const members = compactRoomMembers(memberResult.rows);
  const matchmakingResult = await client.query(
    `SELECT state,
            started_at,
            estimated_seconds,
            ally_bot_count,
            enemy_bot_count,
            matched_room_id::text,
            match_id::text,
            matched_at,
            GREATEST(
              0,
              FLOOR(
                EXTRACT(
                  EPOCH FROM (COALESCE(matched_at, NOW()) - started_at)
                )
              )
            )::int AS elapsed_seconds
       FROM game_room_matchmaking
      WHERE room_id = $1`,
    [roomId],
  );
  const matchmaking = matchmakingResult.rowCount === 1
    ? {
        ...matchmakingResult.rows[0],
        ally_count: members.length,
        ally_needed: Math.max(
          0,
          Number(roomResult.rows[0].max_players) - members.length,
        ),
        enemy_count: roomResult.rows[0].is_test
          ? TEST_ENEMY_BOT_COUNT
          : 0,
        enemy_needed: roomResult.rows[0].is_test
          ? 0
          : Number(roomResult.rows[0].max_players),
      }
    : null;
  const match = matchmaking?.match_id
    ? await matchPayload(client, matchmaking.match_id, viewerAccountId)
    : null;

  return {
    ...roomResult.rows[0],
    player_count: members.length,
    members,
    matchmaking,
    match,
  };
}

async function currentRoomForCaptain(client, accountId) {
  const currentResult = await client.query(
    `SELECT room.*
       FROM game_room_members current_member
       JOIN game_rooms room ON room.id = current_member.room_id
      WHERE current_member.account_id = $1
      FOR UPDATE OF room`,
    [accountId],
  );
  if (currentResult.rowCount !== 1) {
    throw new GameRoomError(404, "ROOM_NOT_FOUND", "Bạn không ở trong phòng PvP.");
  }
  const room = currentResult.rows[0];
  const captainResult = await client.query(
    `SELECT account_id
       FROM game_room_members
      WHERE room_id = $1
      ORDER BY join_order
      LIMIT 1`,
    [room.id],
  );
  if (
    captainResult.rowCount !== 1
    || String(captainResult.rows[0].account_id) !== String(accountId)
  ) {
    throw new GameRoomError(
      403,
      "CAPTAIN_REQUIRED",
      "Chỉ đội trưởng được thay đổi bản đồ hoặc bắt đầu trận.",
    );
  }
  return room;
}

async function leaveCurrentRoom(client, accountId) {
  const currentResult = await client.query(
    `DELETE FROM game_room_members
      WHERE account_id = $1
      RETURNING room_id`,
    [accountId],
  );
  if (currentResult.rowCount === 0) {
    return null;
  }
  const roomId = currentResult.rows[0].room_id;
  const matchResult = await client.query(
    `SELECT match.*
       FROM game_room_matchmaking matchmaking
       JOIN game_matches match ON match.id = matchmaking.match_id
      WHERE matchmaking.room_id = $1
        AND match.phase NOT IN ('active', 'cancelled')
      FOR UPDATE OF match`,
    [roomId],
  );
  if (matchResult.rowCount === 1) {
    await resetMatchRooms(client, matchResult.rows[0]);
  }
  await client.query(
    `UPDATE game_rooms
        SET status = 'waiting', updated_at = NOW()
      WHERE id = $1 AND status = 'matching'`,
    [roomId],
  );
  await client.query(
    "DELETE FROM game_room_matchmaking WHERE room_id = $1",
    [roomId],
  );
  await client.query(
    `UPDATE game_rooms room
        SET status = 'waiting', updated_at = NOW()
      WHERE room.id = $1
        AND room.is_test
        AND NOT EXISTS (
          SELECT 1 FROM game_room_members member WHERE member.room_id = room.id
        )`,
    [roomId],
  );
  await client.query(
    `DELETE FROM game_rooms room
      WHERE room.id = $1
        AND NOT room.is_test
        AND NOT EXISTS (
          SELECT 1 FROM game_room_members member WHERE member.room_id = room.id
        )`,
    [roomId],
  );
  return roomId;
}

async function joinLockedRoom(client, accountId, room) {
  const currentResult = await client.query(
    `SELECT room_id
       FROM game_room_members
      WHERE account_id = $1`,
    [accountId],
  );
  if (
    currentResult.rowCount === 1
    && String(currentResult.rows[0].room_id) === String(room.id)
  ) {
    return roomPayload(client, room.id, accountId);
  }

  if (room.status !== "waiting" && room.status !== "matching") {
    throw new GameRoomError(409, "ROOM_ALREADY_RUNNING", "Phòng đã bắt đầu trận đấu.");
  }

  const countResult = await client.query(
    `SELECT COUNT(*)::int AS count
       FROM game_room_members
      WHERE room_id = $1`,
    [room.id],
  );
  if (countResult.rows[0].count >= room.max_players) {
    throw new GameRoomError(409, "ROOM_FULL", "Phòng đã đủ người.");
  }

  await leaveCurrentRoom(client, accountId);
  await client.query(
    `INSERT INTO game_room_members(room_id, account_id)
     VALUES ($1, $2)`,
    [room.id, accountId],
  );
  await client.query(
    "UPDATE game_rooms SET updated_at = NOW() WHERE id = $1",
    [room.id],
  );
  return roomPayload(client, room.id, accountId);
}

export async function listGameRooms(tabValue) {
  const tab = normalizedTab(tabValue);
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const result = await client.query(
      `SELECT room.room_code::text,
              room.tab_key,
              room.room_name,
              room.mode_key,
              room.map_key,
              COALESCE(game_map.display_name, room.map_key) AS map_name,
              COALESCE(game_map.thumbnail_asset_path, '')
                  AS map_thumbnail_asset_path,
              room.max_players,
              room.status,
              room.is_test,
              COUNT(member.account_id)::int AS player_count
         FROM game_rooms room
         LEFT JOIN game_maps game_map ON game_map.map_key = room.map_key
         LEFT JOIN game_room_members member ON member.room_id = room.id
        WHERE room.tab_key = $1
          AND room.is_test = ($1 = 'test')
        GROUP BY room.id, game_map.map_key
        ORDER BY room.is_test DESC, room.created_at, room.id
        LIMIT 100`,
      [tab],
    );
    return result.rows;
  });
}

export async function listGameMaps() {
  const result = await pool.query(
    `SELECT map_key, display_name, thumbnail_asset_path
       FROM game_maps
      WHERE enabled
      ORDER BY sort_order, map_key`,
  );
  return result.rows;
}

export async function currentGameRoom(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const current = await client.query(
      "SELECT room_id FROM game_room_members WHERE account_id = $1",
      [accountId],
    );
    return current.rowCount === 1
      ? roomPayload(client, current.rows[0].room_id, accountId)
      : null;
  });
}

export async function joinGameRoom(accountId, roomCodeValue) {
  const roomCode = normalizedRoomCode(roomCodeValue);
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const room = await roomByCodeForUpdate(client, roomCode);
    return joinLockedRoom(client, accountId, room);
  });
}

export async function quickJoinGameRoom(accountId, tabValue) {
  const tab = normalizedTab(tabValue);
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const candidateResult = await client.query(
      `SELECT room.*
         FROM game_rooms room
        WHERE room.tab_key = $1
          AND room.is_test = ($1 = 'test')
          AND room.status IN ('waiting', 'matching')
          AND room.max_players = 5
          AND (
            SELECT COUNT(*) FROM game_room_members member
             WHERE member.room_id = room.id
          ) < room.max_players
        ORDER BY (room.status = 'matching') DESC,
        (
          SELECT COUNT(*) FROM game_room_members member
           WHERE member.room_id = room.id
        ) DESC,
        room.created_at,
        room.id
        LIMIT 1
        FOR UPDATE`,
      [tab],
    );
    if (candidateResult.rowCount !== 1) {
      throw new GameRoomError(404, "NO_AVAILABLE_ROOM", "Không có phòng 5 người đang chờ.");
    }
    return joinLockedRoom(client, accountId, candidateResult.rows[0]);
  });
}

export async function createGameRoom(accountId, input) {
  const tab = normalizedTab(input?.tab_key);
  if (tab === "test") {
    throw new GameRoomError(403, "TEST_ROOM_FIXED", "Phòng TEST chỉ do hệ thống tạo sẵn.");
  }
  const roomName = String(input?.room_name ?? "").normalize("NFKC").trim();
  if (roomName.length < 1 || Array.from(roomName).length > ROOM_NAME_MAX_LENGTH) {
    throw new GameRoomError(400, "INVALID_ROOM_NAME", "Tên phòng dài tối đa 40 ký tự.");
  }
  const modeKey = String(input?.mode_key ?? "free").trim().toLowerCase();
  if (!VALID_MODES.has(modeKey)) {
    throw new GameRoomError(400, "INVALID_ROOM_MODE", "Chế độ phòng không hợp lệ.");
  }
  const mapKey = normalizedMapKey(input?.map_key ?? "random");

  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const mapResult = await client.query(
      "SELECT 1 FROM game_maps WHERE map_key = $1 AND enabled",
      [mapKey],
    );
    if (mapResult.rowCount !== 1) {
      throw new GameRoomError(400, "MAP_NOT_AVAILABLE", "Bản đồ chưa được mở trên server.");
    }
    await leaveCurrentRoom(client, accountId);
    const roomResult = await client.query(
      `INSERT INTO game_rooms(
         tab_key,
         room_name,
         mode_key,
         map_key,
         max_players,
         created_by_account_id
       )
       VALUES ($1, $2, $3, $4, 5, $5)
       RETURNING *`,
      [tab, roomName, modeKey, mapKey, accountId],
    );
    const room = roomResult.rows[0];
    await client.query(
      `INSERT INTO game_room_members(room_id, account_id)
       VALUES ($1, $2)`,
      [room.id, accountId],
    );
    return roomPayload(client, room.id, accountId);
  });
}

export async function selectGameRoomMap(accountId, mapKeyValue) {
  const mapKey = normalizedMapKey(mapKeyValue);
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const room = await currentRoomForCaptain(client, accountId);
    if (room.status !== "waiting") {
      throw new GameRoomError(409, "ROOM_ALREADY_RUNNING", "Phòng đã bắt đầu trận đấu.");
    }
    const mapResult = await client.query(
      "SELECT 1 FROM game_maps WHERE map_key = $1 AND enabled",
      [mapKey],
    );
    if (mapResult.rowCount !== 1) {
      throw new GameRoomError(404, "MAP_NOT_AVAILABLE", "Bản đồ chưa được mở trên server.");
    }
    await client.query(
      `UPDATE game_rooms
          SET map_key = $1, updated_at = NOW()
        WHERE id = $2`,
      [mapKey, room.id],
    );
    return roomPayload(client, room.id, accountId);
  });
}

export async function startGameRoom(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const room = await currentRoomForCaptain(client, accountId);
    if (room.status === "waiting") {
      await client.query(
        `UPDATE game_rooms
            SET status = 'matching', updated_at = NOW()
          WHERE id = $1`,
        [room.id],
      );
      await client.query(
        `INSERT INTO game_room_matchmaking(
           room_id,
           state,
           started_at,
           estimated_seconds,
           ally_bot_count,
           enemy_bot_count,
           matched_room_id,
           matched_at,
           updated_at
         )
         VALUES ($1, 'searching', NOW(), $2, 0, $3, NULL, NULL, NOW())
         ON CONFLICT (room_id) DO UPDATE
         SET state = 'searching',
             started_at = NOW(),
             estimated_seconds = EXCLUDED.estimated_seconds,
             ally_bot_count = 0,
             enemy_bot_count = EXCLUDED.enemy_bot_count,
             matched_room_id = NULL,
             matched_at = NULL,
             updated_at = NOW()`,
        [
          room.id,
          room.is_test
            ? TEST_MATCHMAKING_ESTIMATED_SECONDS
            : MATCHMAKING_ESTIMATED_SECONDS,
          room.is_test ? TEST_ENEMY_BOT_COUNT : 0,
        ],
      );
    }
    return roomPayload(client, room.id, accountId);
  });
}

export async function cancelGameRoomMatchmaking(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    await cleanupStaleRooms(client);
    const room = await currentRoomForCaptain(client, accountId);
    if (room.status !== "matching") {
      throw new GameRoomError(
        409,
        "ROOM_NOT_MATCHING",
        "Phòng không ở trạng thái đang phối hợp.",
      );
    }
    const matchResult = await client.query(
      `SELECT match.*
         FROM game_room_matchmaking matchmaking
         JOIN game_matches match ON match.id = matchmaking.match_id
        WHERE matchmaking.room_id = $1
        FOR UPDATE OF match`,
      [room.id],
    );
    if (
      matchResult.rowCount === 1
      && !["active", "cancelled"].includes(matchResult.rows[0].phase)
    ) {
      await resetMatchRooms(client, matchResult.rows[0]);
    }
    await client.query(
      `UPDATE game_rooms
          SET status = 'waiting', updated_at = NOW()
        WHERE id = $1`,
      [room.id],
    );
    await client.query(
      "DELETE FROM game_room_matchmaking WHERE room_id = $1",
      [room.id],
    );
    return roomPayload(client, room.id, accountId);
  });
}

async function currentMatchForAccount(client, accountId) {
  const result = await client.query(
    `SELECT match.*
       FROM game_match_participants participant
       JOIN game_matches match ON match.id = participant.match_id
      WHERE participant.account_id = $1
        AND match.phase <> 'cancelled'
      ORDER BY match.created_at DESC, match.id DESC
      LIMIT 1
      FOR UPDATE OF match`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    throw new GameRoomError(404, "MATCH_NOT_FOUND", "KhĂ´ng cĂ³ tráº­n Ä‘áº¥u Ä‘ang chá».");
  }
  return result.rows[0];
}

async function currentMatchTeamForAccount(client, accountId) {
  const result = await client.query(
    `SELECT participant.match_id::text,
            participant.team_no,
            participant.display_name,
            match.phase,
            match.battle_ended_at
       FROM game_match_participants participant
       JOIN game_matches match ON match.id = participant.match_id
      WHERE participant.account_id = $1
        AND NOT participant.is_bot
        AND match.phase <> 'cancelled'
      ORDER BY match.created_at DESC, match.id DESC
      LIMIT 1`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    throw new GameRoomError(
      404,
      "MATCH_NOT_FOUND",
      "Không có trận đấu đang chờ.",
    );
  }
  const context = result.rows[0];
  const resultChatOpen = context.phase === "finished"
    && context.battle_ended_at
    && Date.now() - new Date(context.battle_ended_at).getTime() <= 2 * 60 * 1000;
  if (
    !["selecting", "loading", "transition", "active"].includes(context.phase)
    && !resultChatOpen
  ) {
    throw new GameRoomError(
      409,
      "MATCH_CHAT_CLOSED",
      "Chat trận chỉ hoạt động khi trận đấu đang diễn ra.",
    );
  }
  return context;
}

export async function listGameMatchTeamMessages(
  accountId,
  afterIdValue = 0,
  limitValue = 50,
) {
  const requestedAfterId = String(afterIdValue ?? "0");
  const afterId = /^\d+$/.test(requestedAfterId) ? requestedAfterId : "0";
  const requestedLimit = Number.parseInt(String(limitValue ?? "50"), 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(50, Math.max(1, requestedLimit))
    : 50;
  const context = await currentMatchTeamForAccount(pool, accountId);
  const result = await pool.query(
    `SELECT message.id::text,
            message.sender_account_id::text AS sender_account_id,
            sender.display_name AS sender_name,
            message.body,
            message.created_at
       FROM game_match_team_messages message
       JOIN game_match_participants sender
         ON sender.match_id = message.match_id
        AND sender.account_id = message.sender_account_id
      WHERE message.match_id = $1
        AND message.team_no = $2
        AND message.id > $3::bigint
      ORDER BY message.id
      LIMIT $4`,
    [context.match_id, context.team_no, afterId, limit],
  );
  return {
    channel: "team",
    match_id: context.match_id,
    team_no: context.team_no,
    messages: result.rows,
  };
}

export async function sendGameMatchTeamMessage(accountId, message) {
  return withTransaction(async (client) => {
    const context = await currentMatchTeamForAccount(client, accountId);
    const result = await client.query(
      `INSERT INTO game_match_team_messages (
         match_id,
         team_no,
         sender_account_id,
         body
       )
       VALUES ($1, $2, $3, $4)
       RETURNING id::text,
                 sender_account_id::text,
                 body,
                 created_at`,
      [context.match_id, context.team_no, accountId, message],
    );
    return {
      ...result.rows[0],
      sender_name: context.display_name,
    };
  });
}

export async function listGameMatchBattleMessages(
  accountId,
  afterIdValue = 0,
  limitValue = 50,
) {
  const requestedAfterId = String(afterIdValue ?? "0");
  const afterId = /^\d+$/.test(requestedAfterId) ? requestedAfterId : "0";
  const requestedLimit = Number.parseInt(String(limitValue ?? "50"), 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(50, Math.max(1, requestedLimit))
    : 50;
  const context = await currentMatchTeamForAccount(pool, accountId);
  const result = await pool.query(
    `SELECT message.id::text,
            message.sender_account_id::text AS sender_account_id,
            sender.display_name AS sender_name,
            message.body,
            message.created_at
       FROM game_match_battle_messages message
       JOIN game_match_participants sender
         ON sender.match_id = message.match_id
        AND sender.account_id = message.sender_account_id
      WHERE message.match_id = $1
        AND message.id > $2::bigint
      ORDER BY message.id
      LIMIT $3`,
    [context.match_id, afterId, limit],
  );
  return {
    channel: "battle",
    match_id: context.match_id,
    messages: result.rows,
  };
}

export async function sendGameMatchBattleMessage(accountId, message) {
  return withTransaction(async (client) => {
    const context = await currentMatchTeamForAccount(client, accountId);
    const result = await client.query(
      `INSERT INTO game_match_battle_messages (
         match_id,
         sender_account_id,
         body
       )
       VALUES ($1, $2, $3)
       RETURNING id::text, sender_account_id::text, body, created_at`,
      [context.match_id, accountId, message],
    );
    return {
      ...result.rows[0],
      sender_name: context.display_name,
    };
  });
}

export async function currentGameMatch(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    return matchPayload(client, match.id, accountId);
  });
}

export async function confirmGameMatch(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    const currentResult = await client.query(
      "SELECT phase FROM game_matches WHERE id = $1",
      [match.id],
    );
    const phase = currentResult.rows[0]?.phase;
    if (phase === "confirming") {
      await client.query(
        `UPDATE game_match_participants
            SET confirmed = TRUE,
                confirmed_at = COALESCE(confirmed_at, NOW()),
                updated_at = NOW()
          WHERE match_id = $1
            AND account_id = $2
            AND NOT is_bot`,
        [match.id, accountId],
      );
      await advanceMatchFlow(client, match.id);
    } else if (!["selecting", "loading", "transition", "active"].includes(phase)) {
      throw new GameRoomError(409, "MATCH_CONFIRM_CLOSED", "Thá»i gian xĂ¡c nháº­n tráº­n Ä‘Ă£ káº¿t thĂºc.");
    }
    return matchPayload(client, match.id, accountId);
  });
}

export async function selectGameMatchTank(accountId, tankKeyValue) {
  const tankKey = String(tankKeyValue ?? "").trim().toLowerCase();
  if (!/^[a-z0-9_]{1,64}$/.test(tankKey)) {
    throw new GameRoomError(400, "INVALID_TANK", "Tank khĂ´ng há»£p lá»‡.");
  }
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    const phaseResult = await client.query(
      "SELECT phase FROM game_matches WHERE id = $1",
      [match.id],
    );
    if (phaseResult.rows[0]?.phase !== "selecting") {
      throw new GameRoomError(409, "TANK_SELECTION_CLOSED", "KhĂ´ng pháº£i giai Ä‘oáº¡n chá»n Tank.");
    }
    const tankResult = await client.query(
      `SELECT tank.tank_key,
              tank.display_name,
              tank.preview_asset_key,
              tank.battle_kit_key,
              player_tank.level AS tank_level,
              equipped_skin.skin_key,
              equipped_skin.display_name AS skin_name,
              equipped_skin.preview_asset_key AS skin_preview_asset_key
         FROM player_tanks player_tank
         JOIN tanks tank ON tank.id = player_tank.tank_id
         LEFT JOIN tank_skins equipped_skin
                ON equipped_skin.id = player_tank.equipped_skin_id
        WHERE player_tank.account_id = $1
          AND tank.tank_key = $2
          AND tank.enabled`,
      [accountId, tankKey],
    );
    if (tankResult.rowCount !== 1) {
      throw new GameRoomError(403, "TANK_NOT_OWNED", "Báº¡n chÆ°a sá»Ÿ há»¯u Tank nĂ y.");
    }
    const tank = tankResult.rows[0];
    if (!tank.battle_kit_key) {
      throw new GameRoomError(
        409,
        "TANK_BATTLE_KIT_UNAVAILABLE",
        "Tank nĂ y chÆ°a cĂ³ bá»™ ká»¹ nÄƒng server, chÆ°a thá»ƒ xuáº¥t tráº­n online.",
      );
    }
    await client.query(
      `UPDATE game_match_participants
          SET tank_key = $1,
              tank_name = $2,
              tank_preview_asset_key = $3,
              tank_level = $4,
              equipped_skin_key = $5,
              equipped_skin_name = $6,
              equipped_skin_preview_asset_key = $7,
              deployed = FALSE,
              deployed_at = NULL,
              load_progress = 0,
              load_ready = FALSE,
              updated_at = NOW()
        WHERE match_id = $8
          AND account_id = $9
          AND NOT is_bot`,
      [
        tank.tank_key,
        tank.display_name,
        tank.preview_asset_key,
        tank.tank_level,
        tank.skin_key,
        tank.skin_name,
        tank.skin_preview_asset_key,
        match.id,
        accountId,
      ],
    );
    return matchPayload(client, match.id, accountId);
  });
}

export async function equipGameMatchSkin(accountId, tankKeyValue, skinKeyValue) {
  const tankKey = String(tankKeyValue ?? "").trim().toLowerCase();
  const skinKey = String(skinKeyValue ?? "").trim().toLowerCase();
  if (!/^[a-z0-9_]{1,64}$/.test(tankKey)) {
    throw new GameRoomError(400, "INVALID_TANK", "Tank khÃ´ng hợp lệ.");
  }
  if (!/^[a-z0-9_]{1,64}$/.test(skinKey)) {
    throw new GameRoomError(400, "INVALID_SKIN", "Skin khÃ´ng hợp lệ.");
  }
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    const phaseResult = await client.query(
      "SELECT phase FROM game_matches WHERE id = $1",
      [match.id],
    );
    if (phaseResult.rows[0]?.phase !== "selecting") {
      throw new GameRoomError(
        409,
        "SKIN_SELECTION_CLOSED",
        "KhÃ´ng phải giai đoạn chọn Skin.",
      );
    }
    const participantResult = await client.query(
      `SELECT tank_key
         FROM game_match_participants
        WHERE match_id = $1
          AND account_id = $2
          AND NOT is_bot
        FOR UPDATE`,
      [match.id, accountId],
    );
    if (participantResult.rowCount !== 1 || participantResult.rows[0].tank_key !== tankKey) {
      throw new GameRoomError(
        409,
        "MATCH_TANK_MISMATCH",
        "Skin phải thuộc Tank đang được chọn trong trận.",
      );
    }
    const ownedResult = await client.query(
      `SELECT player_tank.id AS player_tank_id,
              skin.id AS tank_skin_id,
              skin.skin_key,
              skin.display_name AS skin_name,
              skin.preview_asset_key AS skin_preview_asset_key
         FROM player_tanks player_tank
         JOIN tanks tank ON tank.id = player_tank.tank_id
         JOIN tank_skins skin
           ON skin.tank_id = tank.id
          AND skin.skin_key = $3
          AND skin.enabled
         JOIN player_tank_skins owned_skin
           ON owned_skin.account_id = player_tank.account_id
          AND owned_skin.tank_skin_id = skin.id
        WHERE player_tank.account_id = $1
          AND tank.tank_key = $2
          AND tank.enabled
        FOR UPDATE OF player_tank, owned_skin`,
      [accountId, tankKey, skinKey],
    );
    if (ownedResult.rowCount !== 1) {
      throw new GameRoomError(409, "SKIN_NOT_OWNED", "Bạn chưa sở hữu Skin nÃ y.");
    }
    const skin = ownedResult.rows[0];
    await client.query(
      "UPDATE player_tanks SET equipped_skin_id = $1 WHERE id = $2",
      [skin.tank_skin_id, skin.player_tank_id],
    );
    // Do not reset deployed/load state: only the skin snapshot changes.
    await client.query(
      `UPDATE game_match_participants
          SET equipped_skin_key = $1,
              equipped_skin_name = $2,
              equipped_skin_preview_asset_key = $3,
              updated_at = NOW()
        WHERE match_id = $4
          AND account_id = $5
          AND NOT is_bot`,
      [
        skin.skin_key,
        skin.skin_name,
        skin.skin_preview_asset_key,
        match.id,
        accountId,
      ],
    );
    return matchPayload(client, match.id, accountId);
  });
}

export async function deployGameMatchTank(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    const participantResult = await client.query(
      `SELECT match.phase,
              participant.tank_key,
              participant.deployed,
              tank.battle_kit_key
         FROM game_matches match
         JOIN game_match_participants participant
           ON participant.match_id = match.id
         LEFT JOIN tanks tank
           ON tank.tank_key = participant.tank_key
          AND tank.enabled
        WHERE match.id = $1
          AND participant.account_id = $2`,
      [match.id, accountId],
    );
    const participant = participantResult.rows[0];
    if (participant?.phase === "selecting" && !participant.battle_kit_key) {
      throw new GameRoomError(
        409,
        "TANK_BATTLE_KIT_UNAVAILABLE",
        "Tank nĂ y chÆ°a cĂ³ bá»™ ká»¹ nÄƒng server, chÆ°a thá»ƒ xuáº¥t tráº­n online.",
      );
    }
    if (participant?.phase !== "selecting") {
      if (["loading", "transition", "active"].includes(participant?.phase)) {
        return matchPayload(client, match.id, accountId);
      }
      throw new GameRoomError(409, "TANK_SELECTION_CLOSED", "KhĂ´ng pháº£i giai Ä‘oáº¡n chá»n Tank.");
    }
    if (!participant.tank_key) {
      throw new GameRoomError(409, "TANK_REQUIRED", "HĂ£y chá»n Tank trÆ°á»›c khi xuáº¥t chiáº¿n.");
    }
    await client.query(
      `UPDATE game_match_participants
          SET deployed = TRUE,
              deployed_at = COALESCE(deployed_at, NOW()),
              updated_at = NOW()
        WHERE match_id = $1
          AND account_id = $2
          AND NOT is_bot`,
      [match.id, accountId],
    );
    await advanceMatchFlow(client, match.id);
    return matchPayload(client, match.id, accountId);
  });
}

export async function reportGameMatchLoad(accountId, progressValue) {
  const progress = Number(progressValue);
  if (!Number.isInteger(progress) || progress < 0 || progress > 100) {
    throw new GameRoomError(400, "INVALID_LOAD_PROGRESS", "Tiáº¿n Ä‘á»™ táº£i pháº£i tá»« 0 Ä‘áº¿n 100.");
  }
  return withTransaction(async (client) => {
    await lockRooms(client);
    const match = await currentMatchForAccount(client, accountId);
    await advanceMatchFlow(client, match.id);
    const phaseResult = await client.query(
      "SELECT phase FROM game_matches WHERE id = $1",
      [match.id],
    );
    const phase = phaseResult.rows[0]?.phase;
    if (!["loading", "transition", "active"].includes(phase)) {
      throw new GameRoomError(409, "MATCH_NOT_LOADING", "Tráº­n Ä‘áº¥u chÆ°a táº£i dá»¯ liá»‡u.");
    }
    if (phase === "loading") {
      await client.query(
        `UPDATE game_match_participants
            SET load_progress = GREATEST(load_progress, $1),
                load_ready = GREATEST(load_progress, $1) = 100,
                updated_at = NOW()
          WHERE match_id = $2
            AND account_id = $3
            AND NOT is_bot`,
        [progress, match.id, accountId],
      );
      await advanceMatchFlow(client, match.id);
    }
    return matchPayload(client, match.id, accountId);
  });
}

export async function leaveGameRoom(accountId) {
  return withTransaction(async (client) => {
    await lockRooms(client);
    const roomId = await leaveCurrentRoom(client, accountId);
    return { left: roomId !== null };
  });
}

export async function removeAccountFromGameRoom(accountId) {
  try {
    await leaveGameRoom(accountId);
  } catch (error) {
    console.error("Could not remove account from game room", error);
  }
}
