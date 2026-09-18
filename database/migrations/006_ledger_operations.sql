CREATE TABLE IF NOT EXISTS ledger_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), account_id uuid REFERENCES accounts(id),
 bucket text NOT NULL CHECK(bucket IN ('PAPER_CASH','TRADING_CAPITAL','REALIZED_PROFIT','FEES','LONG_TERM_RESERVE','WITHDRAWAL_RESERVE')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(user_id, account_id, bucket)
);
CREATE TABLE IF NOT EXISTS ledger_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), account_id uuid REFERENCES accounts(id),
 transaction_type text NOT NULL, reference_entity text, reference_id uuid, idempotency_key text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS ledger_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), transaction_id uuid NOT NULL REFERENCES ledger_transactions(id), ledger_account_id uuid NOT NULL REFERENCES ledger_accounts(id),
 direction text NOT NULL CHECK(direction IN ('DEBIT','CREDIT')), amount_minor bigint NOT NULL CHECK(amount_minor>0), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ledger_transactions_owner ON ledger_transactions(user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS ledger_entries_transaction ON ledger_entries(transaction_id);
CREATE TABLE IF NOT EXISTS allocation_settings (
 user_id uuid PRIMARY KEY REFERENCES users(id), short_term_bps integer NOT NULL DEFAULT 5000 CHECK(short_term_bps BETWEEN 0 AND 10000), long_term_bps integer NOT NULL DEFAULT 3000 CHECK(long_term_bps BETWEEN 0 AND 10000), withdrawal_bps integer NOT NULL DEFAULT 2000 CHECK(withdrawal_bps BETWEEN 0 AND 10000), updated_at timestamptz NOT NULL DEFAULT now(), CHECK(short_term_bps+long_term_bps+withdrawal_bps=10000)
);
CREATE TABLE IF NOT EXISTS allocation_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), amount_minor bigint NOT NULL CHECK(amount_minor>0), short_minor bigint NOT NULL, long_minor bigint NOT NULL, withdrawal_minor bigint NOT NULL, ledger_transaction_id uuid REFERENCES ledger_transactions(id), idempotency_key text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), event_type text NOT NULL, entity text, entity_id uuid, payload jsonb NOT NULL DEFAULT '{}', read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_owner ON notifications(user_id,created_at DESC);
CREATE OR REPLACE FUNCTION reject_ledger_mutation() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Ledger entries are immutable'; END $$;
DROP TRIGGER IF EXISTS ledger_entries_immutable ON ledger_entries;
CREATE TRIGGER ledger_entries_immutable BEFORE UPDATE OR DELETE ON ledger_entries FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
