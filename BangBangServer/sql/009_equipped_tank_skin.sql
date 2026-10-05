BEGIN;

ALTER TABLE player_tanks
    ADD COLUMN IF NOT EXISTS equipped_skin_id BIGINT
        REFERENCES tank_skins(id) ON DELETE SET NULL;

UPDATE player_tanks player_tank
SET equipped_skin_id = default_skin.id
FROM tank_skins default_skin
WHERE default_skin.tank_id = player_tank.tank_id
  AND default_skin.is_default
  AND default_skin.enabled
  AND player_tank.equipped_skin_id IS NULL
  AND EXISTS (
      SELECT 1
      FROM player_tank_skins owned_skin
      WHERE owned_skin.account_id = player_tank.account_id
        AND owned_skin.tank_skin_id = default_skin.id
  );

CREATE INDEX IF NOT EXISTS player_tanks_equipped_skin_idx
    ON player_tanks(equipped_skin_id)
    WHERE equipped_skin_id IS NOT NULL;

COMMIT;
