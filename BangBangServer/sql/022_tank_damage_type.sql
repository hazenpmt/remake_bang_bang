BEGIN;

ALTER TABLE tanks
    ADD COLUMN IF NOT EXISTS damage_type VARCHAR(16) NOT NULL DEFAULT 'physical'
        CHECK (damage_type IN ('physical', 'energy'));

UPDATE tanks
SET damage_type = 'physical'
WHERE tank_key = 'gangtiexia03';

COMMIT;
