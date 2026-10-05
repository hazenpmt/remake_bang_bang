BEGIN;

DELETE FROM player_tank_skins owned_skin
USING tank_skins skin, tanks tank
WHERE owned_skin.tank_skin_id = skin.id
  AND skin.tank_id = tank.id
  AND tank.tank_key = 'starter_tank';

DELETE FROM player_tanks owned
USING tanks tank
WHERE owned.tank_id = tank.id
  AND tank.tank_key = 'starter_tank';

DELETE FROM tanks
WHERE tank_key = 'starter_tank';

-- Chuyển các hồ sơ cũ từng nhận Tank tạm sang đúng quà Iron Man.
-- Người đã sở hữu Iron Man vẫn giữ trạng thái claimed và không được cấp lại.
INSERT INTO player_rewards (
    account_id,
    reward_key,
    status,
    offered_at,
    claimed_at
)
SELECT
    profile.account_id,
    'newcomer_iron_man',
    'pending',
    NOW(),
    NULL
FROM player_profiles profile
WHERE NOT EXISTS (
    SELECT 1
    FROM player_tanks owned
    JOIN tanks tank ON tank.id = owned.tank_id
    WHERE owned.account_id = profile.account_id
      AND tank.tank_key = 'gangtiexia03'
)
ON CONFLICT (account_id, reward_key) DO UPDATE
SET status = 'pending',
    offered_at = NOW(),
    claimed_at = NULL;

COMMIT;
