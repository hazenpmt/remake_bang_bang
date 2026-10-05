BEGIN;

ALTER TABLE tanks
    ADD COLUMN IF NOT EXISTS battle_kit_key VARCHAR(64);

UPDATE tanks
   SET battle_kit_key = 'ironman_v1'
 WHERE tank_key = 'gangtiexia03'
   AND battle_kit_key IS DISTINCT FROM 'ironman_v1';

ALTER TABLE game_match_battle_participants
    ADD COLUMN IF NOT EXISTS battle_kit_key VARCHAR(64);

UPDATE game_match_battle_participants battle
   SET battle_kit_key = tank.battle_kit_key
  FROM tanks tank
 WHERE tank.tank_key = battle.tank_key
   AND battle.battle_kit_key IS NULL;

COMMIT;
