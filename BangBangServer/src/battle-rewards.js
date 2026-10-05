import { applyCharacterExperience } from "./character-levels.js";

export function calculateBattleReward(participant, winnerTeamNo) {
  const kills = Math.max(0, Number(participant.kills) || 0);
  const deaths = Math.max(0, Number(participant.deaths) || 0);
  const assists = Math.max(0, Number(participant.assists) || 0);
  const teamNo = Number(participant.team_no);
  const winner = Number(winnerTeamNo);
  const outcome = winner === 0 ? "draw" : (winner === teamNo ? "win" : "lose");
  return {
    outcome,
    experience: Math.max(0, Math.round(
      50 + kills * 10 + assists * 5 + (outcome === "win" ? 25 : 0),
    )),
    silver: Math.max(0, Math.round(kills * 5 + assists * 3 - deaths * 2)),
  };
}

export async function settleBattleRewards(
  client,
  match,
  participants,
  winnerTeamNo,
  now = new Date(),
) {
  const rewards = [];
  for (const participant of participants) {
    if (participant.is_bot || participant.account_id == null) {
      continue;
    }
    const existing = await client.query(
      `SELECT *
         FROM game_match_battle_rewards
        WHERE match_id = $1 AND account_id = $2`,
      [match.id, participant.account_id],
    );
    if (existing.rowCount === 1) {
      rewards.push(existing.rows[0]);
      continue;
    }
    const state = await client.query(
      `SELECT profile.level,
              profile.experience,
              currency.silver
         FROM player_profiles profile
         JOIN player_currencies currency
           ON currency.account_id = profile.account_id
        WHERE profile.account_id = $1
        FOR UPDATE OF profile, currency`,
      [participant.account_id],
    );
    if (state.rowCount !== 1) {
      throw new Error(`Battle reward profile missing for account ${participant.account_id}.`);
    }
    const before = state.rows[0];
    const reward = calculateBattleReward(participant, winnerTeamNo);
    const progression = applyCharacterExperience(
      before.level,
      before.experience,
      reward.experience,
    );
    const silverAfter = Number(before.silver) + reward.silver;
    await client.query(
      `UPDATE player_profiles
          SET level = $2,
              experience = $3,
              updated_at = NOW()
        WHERE account_id = $1`,
      [participant.account_id, progression.level, progression.experience],
    );
    await client.query(
      `UPDATE player_currencies
          SET silver = $2,
              updated_at = NOW()
        WHERE account_id = $1`,
      [participant.account_id, silverAfter],
    );
    const inserted = await client.query(
      `INSERT INTO game_match_battle_rewards (
         match_id, team_no, slot_no, account_id, outcome,
         tank_key, kills, deaths, assists,
         experience_reward, silver_reward,
         level_before, level_after,
         experience_before, experience_after,
         silver_before, silver_after, created_at
       ) VALUES (
         $1, $2, $3, $4, $5,
         $6, $7, $8, $9,
         $10, $11, $12, $13, $14, $15, $16, $17, $18
       )
       RETURNING *`,
      [
        match.id,
        participant.team_no,
        participant.slot_no,
        participant.account_id,
        reward.outcome,
        participant.tank_key,
        Number(participant.kills),
        Number(participant.deaths),
        Number(participant.assists),
        reward.experience,
        reward.silver,
        Number(before.level),
        progression.level,
        Number(before.experience),
        progression.experience,
        Number(before.silver),
        silverAfter,
        now,
      ],
    );
    const transactionKey = `battle:${match.id}:${participant.account_id}`;
    await client.query(
      `INSERT INTO economy_ledger (
         account_id, transaction_key, entry_index,
         asset_kind, asset_key, delta, balance_after,
         reason, reference_type, reference_id, metadata, created_at
       ) VALUES (
         $1, $2, 0,
         'experience', 'character_exp', $3, $4,
         'battle_reward', 'game_match', $5, $6::jsonb, $7
       )`,
      [
        participant.account_id,
        transactionKey,
        reward.experience,
        progression.experience,
        String(match.id),
        JSON.stringify({
          outcome: reward.outcome,
          level_before: Number(before.level),
          level_after: progression.level,
        }),
        now,
      ],
    );
    if (reward.silver > 0) {
      await client.query(
        `INSERT INTO economy_ledger (
           account_id, transaction_key, entry_index,
           asset_kind, asset_key, delta, balance_after,
           reason, reference_type, reference_id, metadata, created_at
         ) VALUES (
           $1, $2, 1,
           'currency', 'silver', $3, $4,
           'battle_reward', 'game_match', $5, $6::jsonb, $7
         )`,
        [
          participant.account_id,
          transactionKey,
          reward.silver,
          silverAfter,
          String(match.id),
          JSON.stringify({ outcome: reward.outcome }),
          now,
        ],
      );
    }
    rewards.push(inserted.rows[0]);
  }
  await client.query(
    `UPDATE game_matches
        SET reward_settled_at = COALESCE(reward_settled_at, $2),
            updated_at = NOW()
      WHERE id = $1`,
    [match.id, now],
  );
  match.reward_settled_at = match.reward_settled_at ?? now;
  return rewards;
}
