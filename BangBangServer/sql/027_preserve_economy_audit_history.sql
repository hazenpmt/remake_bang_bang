BEGIN;

-- Purchase orders and the append-only ledger are financial/audit history.
-- Never erase them through an accidental account cascade. Account erasure must
-- be a separate privileged anonymization procedure, not an application DELETE.
ALTER TABLE purchase_orders
    DROP CONSTRAINT IF EXISTS purchase_orders_account_id_fkey;
ALTER TABLE purchase_orders
    ADD CONSTRAINT purchase_orders_account_id_fkey
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT;

ALTER TABLE economy_ledger
    DROP CONSTRAINT IF EXISTS economy_ledger_account_id_fkey;
ALTER TABLE economy_ledger
    ADD CONSTRAINT economy_ledger_account_id_fkey
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT;

COMMIT;
