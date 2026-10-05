BEGIN;

-- Tank selection exposes exactly three gameplay roles.  Keep the value
-- authoritative in the tank catalog; the client only filters/displays it.
UPDATE tanks
SET role_key = 'dps'
WHERE tank_key = 'gangtiexia03'
  AND (role_key IS NULL OR role_key NOT IN ('dps', 'tanker', 'support'));

UPDATE tanks
SET role_key = 'tanker'
WHERE lower(role_key) IN ('tank', 'panzer', 'defender', 'defense');

UPDATE tanks
SET role_key = 'support'
WHERE lower(role_key) IN ('assist', 'healer', 'healing', 'helper');

UPDATE tanks
SET role_key = 'dps'
WHERE lower(role_key) IN ('attack', 'attacker', 'damage', 'damage_dealer');

ALTER TABLE tanks
  DROP CONSTRAINT IF EXISTS tanks_role_key_check;

ALTER TABLE tanks
  ADD CONSTRAINT tanks_role_key_check
  CHECK (role_key IS NULL OR role_key IN ('dps', 'tanker', 'support'));

COMMIT;
