BEGIN;

UPDATE tank_skin_collection_rules
   SET hit_points_percent = 2
 WHERE rule_key = 'quality_a';

COMMIT;
