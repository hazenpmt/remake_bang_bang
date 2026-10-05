BEGIN;

UPDATE tanks
   SET display_name = 'Thạch Hầu'
 WHERE tank_key = 'starter_tank';

COMMIT;
