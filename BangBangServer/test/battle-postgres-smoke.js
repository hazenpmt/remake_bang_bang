import assert from "node:assert/strict";

import { settleBattleRewards } from "../src/battle-rewards.js";
import {
  advanceBattleMatch,
  getBattleSnapshot,
  readBattleSnapshot,
  submitBattleCommand,
} from "../src/battle-runtime.js";
import { pool, withTransaction } from "../src/db.js";

const suffix = String(Date.now()).slice(-8);
const usernames = [`battle_a_${suffix}`, `battle_b_${suffix}`];
const displayNames = [`BA${suffix.slice(-6)}`, `BB${suffix.slice(-6)}`];
const createdAccountIds = [];
const createdRoomIds = [];

async function setup() {
  return withTransaction(async (client) => {
    const tankResult = await client.query(
      "SELECT id, tank_key, display_name, preview_asset_key FROM tanks WHERE tank_key = 'gangtiexia03'",
    );
    assert.equal(tankResult.rowCount, 1);
    const tank = tankResult.rows[0];
    const skinResult = await client.query(
      `SELECT id, skin_key, display_name, preview_asset_key
         FROM tank_skins
        WHERE tank_id = $1 AND is_default
        LIMIT 1`,
      [tank.id],
    );
    assert.equal(skinResult.rowCount, 1);
    const skin = skinResult.rows[0];

    for (let index = 0; index < 2; index += 1) {
      const accountResult = await client.query(
        `INSERT INTO accounts(username, password_hash)
         VALUES ($1, 'battle-smoke-not-a-login')
         RETURNING id`,
        [usernames[index]],
      );
      const accountId = accountResult.rows[0].id;
      createdAccountIds.push(accountId);
      await client.query(
        `INSERT INTO player_profiles(
           account_id, display_name, gender, avatar_key
         ) VALUES ($1, $2, 'male', 'default_male')`,
        [accountId, displayNames[index]],
      );
      await client.query(
        "INSERT INTO player_currencies(account_id) VALUES ($1)",
        [accountId],
      );
      const playerTankResult = await client.query(
        `INSERT INTO player_tanks(
           account_id, tank_id, level, is_primary, equipped_skin_id
         ) VALUES ($1, $2, 1, TRUE, $3)
         RETURNING id`,
        [accountId, tank.id, skin.id],
      );
      assert.equal(playerTankResult.rowCount, 1);
      await client.query(
        `INSERT INTO player_tank_skins(account_id, tank_skin_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [accountId, skin.id],
      );
      const roomResult = await client.query(
        `INSERT INTO game_rooms(
           tab_key, room_name, mode_key, map_key,
           max_players, status, is_test, created_by_account_id
         ) VALUES ('solo', $1, 'free', 'random', 1, 'running', FALSE, $2)
         RETURNING id`,
        [`Battle DB ${index + 1}`, accountId],
      );
      createdRoomIds.push(roomResult.rows[0].id);
      await client.query(
        "INSERT INTO game_room_members(room_id, account_id) VALUES ($1, $2)",
        [roomResult.rows[0].id, accountId],
      );
    }

    const matchResult = await client.query(
      `INSERT INTO game_matches(
         team_a_room_id, team_b_room_id, is_test, phase, map_key,
         confirmation_deadline, activated_at
       ) VALUES ($1, $2, FALSE, 'active', 'random', NOW(), NOW())
       RETURNING id`,
      createdRoomIds,
    );
    const matchId = matchResult.rows[0].id;
    for (let index = 0; index < 2; index += 1) {
      await client.query(
        `INSERT INTO game_match_participants(
           match_id, team_no, slot_no, account_id, is_bot,
           display_name, gender, level, avatar_key,
           tank_key, tank_name, tank_preview_asset_key, tank_level,
           equipped_skin_key, equipped_skin_name,
           equipped_skin_preview_asset_key,
           confirmed, deployed, load_progress, load_ready
         ) VALUES (
           $1, $2, 1, $3, FALSE,
           $4, 'male', 1, 'default_male',
           $5, $6, $7, 1,
           $8, $9, $10,
           TRUE, TRUE, 100, TRUE
         )`,
        [
          matchId,
          index + 1,
          createdAccountIds[index],
          displayNames[index],
          tank.tank_key,
          tank.display_name,
          tank.preview_asset_key,
          skin.skin_key,
          skin.display_name,
          skin.preview_asset_key,
        ],
      );
    }
    return matchId;
  });
}

async function cleanup() {
  await withTransaction(async (client) => {
    if (createdRoomIds.length > 0) {
      await client.query(
        "DELETE FROM game_rooms WHERE id = ANY($1::bigint[])",
        [createdRoomIds],
      );
    }
    if (createdAccountIds.length > 0) {
      await client.query(
        "DELETE FROM accounts WHERE id = ANY($1::bigint[])",
        [createdAccountIds],
      );
    }
  });
}

try {
  const matchId = await setup();
  const first = await getBattleSnapshot(createdAccountIds[0]);
  assert.equal(first.protocol_version, 2);
  assert.equal(first.match_id, String(matchId));
  assert.equal(first.entities.length, 2);
  assert.equal(first.world_entities.length, 49);
  assert.equal(
    first.world_entities.filter((entity) => entity.entity_type === "building").length,
    45,
  );
  assert.equal(
    first.world_entities.filter((entity) => entity.entity_type === "chief").length,
    2,
  );
  assert.equal(
    first.world_entities.filter((entity) => entity.entity_type === "footpoint").length,
    2,
  );
  assert.ok(
    first.world_entities
      .filter((entity) => entity.entity_type === "footpoint")
      .every((entity) => !entity.activated && entity.dead),
  );
  assert.equal(first.last_processed_sequence, 0);
  const realtimeRead = await readBattleSnapshot(createdAccountIds[0]);
  assert.equal(realtimeRead.match_id, String(matchId));
  assert.equal(realtimeRead.revision, first.revision);
  assert.equal(realtimeRead.world_entities.length, 49);

  const moved = await submitBattleCommand(createdAccountIds[0], {
    sequence: 1,
    command: { type: "move", x: 1, y: 0 },
  });
  assert.equal(moved.accepted_sequence, 1);
  assert.equal(moved.replayed, false);
  const replay = await submitBattleCommand(createdAccountIds[0], {
    sequence: 1,
    command: { type: "move", x: 1, y: 0 },
  });
  assert.equal(replay.replayed, true);

  await assert.rejects(
    submitBattleCommand(createdAccountIds[0], {
      sequence: 1,
      command: { type: "move", x: 0, y: 1 },
    }),
    (error) => error.code === "BATTLE_SEQUENCE_CONFLICT",
  );
  await assert.rejects(
    submitBattleCommand(createdAccountIds[0], {
      sequence: 3,
      command: { type: "move", x: 0, y: 0 },
    }),
    (error) => (
      error.code === "BATTLE_SEQUENCE_GAP"
      && error.expectedSequence === 2
    ),
  );

  await pool.query(
    `UPDATE game_match_battle_participants
        SET position_x = CASE WHEN team_no = 1 THEN 800 ELSE 1000 END,
            position_y = 800,
            input_x = 0,
            input_y = 0,
            input_expires_at = NULL
      WHERE match_id = $1`,
    [matchId],
  );
  const attack = await submitBattleCommand(createdAccountIds[0], {
    sequence: 2,
    command: { type: "basic_attack", target_x: 1000, target_y: 800 },
  });
  const enemy = attack.snapshot.entities.find((entity) => entity.team_no === 2);
  assert.ok(
    enemy.hit_points < enemy.maximum_hit_points
      || enemy.shield_points < enemy.maximum_shield_points,
  );
  await assert.rejects(
    submitBattleCommand(createdAccountIds[0], {
      sequence: 3,
      command: { type: "basic_attack", target_x: 1000, target_y: 800 },
    }),
    (error) => error.code === "BATTLE_ATTACK_COOLDOWN",
  );

  // Breaking Iron Man's server-owned shield must trigger the 236% retaliation
  // around the defender. The client cannot forge either the damage or targets.
  await pool.query(
    `UPDATE game_match_battle_participants
        SET shield_points = CASE WHEN team_no = 1 THEN 1 ELSE maximum_shield_points END,
            shield_recharge_at = NULL,
            basic_attack_ready_at = NULL
      WHERE match_id = $1`,
    [matchId],
  );
  const beforeRetaliation = await getBattleSnapshot(createdAccountIds[1]);
  const defenderBefore = beforeRetaliation.entities.find((entity) => entity.team_no === 1);
  const attackerBefore = beforeRetaliation.entities.find((entity) => entity.team_no === 2);
  const retaliation = await submitBattleCommand(createdAccountIds[1], {
    sequence: 1,
    command: { type: "basic_attack", target_x: 800, target_y: 800 },
  });
  const defenderAfter = retaliation.snapshot.entities.find((entity) => entity.team_no === 1);
  const attackerAfter = retaliation.snapshot.entities.find((entity) => entity.team_no === 2);
  assert.ok(
    defenderAfter.hit_points + defenderAfter.shield_points
      < defenderBefore.hit_points + defenderBefore.shield_points,
  );
  assert.ok(
    attackerAfter.hit_points + attackerAfter.shield_points
      < attackerBefore.hit_points + attackerBefore.shield_points,
    "shield-break retaliation did not damage the nearby attacker",
  );

  const reconnect = await getBattleSnapshot(createdAccountIds[0]);
  assert.equal(reconnect.last_processed_sequence, 2);

  // World objects are server-owned targets. A client cannot announce a crate
  // death or spawn a Footpoint: the third verified hit on original crate #46
  // performs both transitions inside the authoritative transaction.
  await pool.query(
    `UPDATE game_match_battle_participants
        SET position_x = 1150,
            position_y = 480,
            basic_attack_ready_at = NULL,
            input_x = 0,
            input_y = 0,
            input_expires_at = NULL
      WHERE match_id = $1 AND account_id = $2`,
    [matchId, createdAccountIds[0]],
  );
  await pool.query(
    `UPDATE game_match_battle_world_entities
        SET hit_count = 2, hit_points = 100
      WHERE match_id = $1 AND entity_key = 'building:46'`,
    [matchId],
  );
  const crateHit = await submitBattleCommand(createdAccountIds[0], {
    sequence: 3,
    command: { type: "basic_attack", target_x: 1296, target_y: 480 },
  });
  const crate = crateHit.snapshot.world_entities.find(
    (entity) => entity.entity_key === "building:46",
  );
  const footpoint = crateHit.snapshot.world_entities.find(
    (entity) => entity.entity_key === "footpoint:46",
  );
  assert.equal(crate.dead, true);
  assert.equal(crate.hit_points, 0);
  assert.equal(footpoint.activated, true);
  assert.equal(footpoint.dead, false);

  // A neutral Footpoint may kill a Tank but can never award score to either
  // team. This guards the team-0 edge case in the shared death path.
  await pool.query(
    `UPDATE game_match_battle_participants
        SET position_x = 1296, position_y = 480
      WHERE match_id = $1 AND account_id = $2`,
    [matchId, createdAccountIds[0]],
  );
  await pool.query(
    `UPDATE game_match_battle_world_entities
        SET active_at = NOW() - INTERVAL '1 second'
      WHERE match_id = $1 AND entity_key = 'footpoint:46'`,
    [matchId],
  );
  await pool.query(
    `UPDATE game_matches
        SET battle_simulated_at = NOW() - INTERVAL '100 milliseconds'
      WHERE id = $1`,
    [matchId],
  );
  const beforeFootpointScore = await pool.query(
    "SELECT team_1_score, team_2_score FROM game_matches WHERE id = $1",
    [matchId],
  );
  assert.equal(await advanceBattleMatch(matchId, new Date()), true);
  const footpointExplosion = await getBattleSnapshot(createdAccountIds[0]);
  const explodedFootpoint = footpointExplosion.world_entities.find(
    (entity) => entity.entity_key === "footpoint:46",
  );
  const afterFootpointScore = await pool.query(
    "SELECT team_1_score, team_2_score FROM game_matches WHERE id = $1",
    [matchId],
  );
  assert.equal(explodedFootpoint.dead, true);
  assert.equal(
    Number(afterFootpointScore.rows[0].team_1_score),
    Number(beforeFootpointScore.rows[0].team_1_score),
  );
  assert.equal(
    Number(afterFootpointScore.rows[0].team_2_score),
    Number(beforeFootpointScore.rows[0].team_2_score),
  );

  // Turret damage is also simulated by the server's fixed 50ms world steps.
  // Moving a target into range and advancing authoritative time must change
  // server HP/shield without accepting any NPC attack command from a client.
  await pool.query(
    `UPDATE game_match_battle_participants
        SET position_x = CASE WHEN team_no = 1 THEN 1492 ELSE position_x END,
            position_y = CASE WHEN team_no = 1 THEN 252 ELSE position_y END
      WHERE match_id = $1`,
    [matchId],
  );
  await pool.query(
    `UPDATE game_match_battle_world_entities
        SET attack_ready_at = NULL
      WHERE match_id = $1 AND entity_key = 'building:68'`,
    [matchId],
  );
  await pool.query(
    `UPDATE game_match_battle_world_entities
        SET activated = FALSE, dead = TRUE, hit_points = 0
      WHERE match_id = $1 AND entity_type = 'footpoint'`,
    [matchId],
  );
  const beforeTurret = await getBattleSnapshot(createdAccountIds[0]);
  const beforeTurretTarget = beforeTurret.entities.find((entity) => entity.team_no === 1);
  await pool.query(
    `UPDATE game_matches
        SET battle_simulated_at = NOW() - INTERVAL '1 second'
      WHERE id = $1`,
    [matchId],
  );
  assert.equal(await advanceBattleMatch(matchId, new Date()), true);
  const afterTurret = await getBattleSnapshot(createdAccountIds[0]);
  const afterTurretTarget = afterTurret.entities.find((entity) => entity.team_no === 1);
  assert.ok(
    afterTurretTarget.hit_points + afterTurretTarget.shield_points
      < beforeTurretTarget.hit_points + beforeTurretTarget.shield_points,
    "authoritative turret did not damage the in-range enemy",
  );

  // Exercise settlement in a transaction that is rolled back, so the smoke
  // proves atomic/idempotent reward accounting without leaving audit fixtures.
  const rewardClient = await pool.connect();
  try {
    await rewardClient.query("BEGIN");
    const matchState = await rewardClient.query(
      "SELECT * FROM game_matches WHERE id = $1 FOR UPDATE",
      [matchId],
    );
    const participantState = await rewardClient.query(
      `SELECT * FROM game_match_battle_participants
        WHERE match_id = $1 ORDER BY team_no, slot_no FOR UPDATE`,
      [matchId],
    );
    participantState.rows[0].kills = 2;
    participantState.rows[0].deaths = 1;
    participantState.rows[0].assists = 3;
    const profileBefore = await rewardClient.query(
      `SELECT profile.level, profile.experience, currency.silver
         FROM player_profiles profile
         JOIN player_currencies currency USING (account_id)
        WHERE profile.account_id = $1`,
      [createdAccountIds[0]],
    );
    const settled = await settleBattleRewards(
      rewardClient,
      matchState.rows[0],
      participantState.rows,
      1,
    );
    assert.equal(settled.length, 2);
    const rewardState = await rewardClient.query(
      `SELECT reward.experience_reward,
              reward.silver_reward,
              reward.level_after,
              reward.experience_after,
              reward.silver_after,
              (SELECT COUNT(*) FROM economy_ledger ledger
                WHERE ledger.transaction_key = $3) AS ledger_count
         FROM game_match_battle_rewards reward
        WHERE reward.match_id = $1 AND reward.account_id = $2`,
      [matchId, createdAccountIds[0], `battle:${matchId}:${createdAccountIds[0]}`],
    );
    assert.equal(Number(rewardState.rows[0].experience_reward), 110);
    assert.equal(Number(rewardState.rows[0].silver_reward), 17);
    assert.equal(Number(rewardState.rows[0].ledger_count), 2);
    assert.equal(
      Number(rewardState.rows[0].silver_after),
      Number(profileBefore.rows[0].silver) + 17,
    );
    await settleBattleRewards(
      rewardClient,
      matchState.rows[0],
      participantState.rows,
      1,
    );
    const replayState = await rewardClient.query(
      `SELECT currency.silver,
              (SELECT COUNT(*) FROM game_match_battle_rewards reward
                WHERE reward.match_id = $2 AND reward.account_id = $1) AS reward_count,
              (SELECT COUNT(*) FROM economy_ledger ledger
                WHERE ledger.transaction_key = $3) AS ledger_count
         FROM player_currencies currency
        WHERE currency.account_id = $1`,
      [createdAccountIds[0], matchId, `battle:${matchId}:${createdAccountIds[0]}`],
    );
    assert.equal(Number(replayState.rows[0].silver), Number(profileBefore.rows[0].silver) + 17);
    assert.equal(Number(replayState.rows[0].reward_count), 1);
    assert.equal(Number(replayState.rows[0].ledger_count), 2);
  } finally {
    await rewardClient.query("ROLLBACK").catch(() => {});
    rewardClient.release();
  }
  console.log("BATTLE_POSTGRES_OK");
} finally {
  await cleanup();
  await pool.end();
}
