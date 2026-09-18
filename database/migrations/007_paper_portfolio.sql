-- Additive extension: legacy portfolio_holdings rows remain untouched.
ALTER TABLE ledger_accounts DROP CONSTRAINT ledger_accounts_bucket_check;
ALTER TABLE ledger_accounts ADD CONSTRAINT ledger_accounts_bucket_check CHECK(bucket IN ('PAPER_CASH','TRADING_CAPITAL','REALIZED_PROFIT','FEES','LONG_TERM_RESERVE','WITHDRAWAL_RESERVE','PORTFOLIO_CASH','PORTFOLIO_COST','PORTFOLIO_PNL','PORTFOLIO_FEES'));
CREATE TABLE portfolios (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL UNIQUE REFERENCES users(id),
 currency text NOT NULL DEFAULT 'THB' CHECK(currency='THB'), mode text NOT NULL DEFAULT 'PAPER' CHECK(mode='PAPER'),
 reconciliation_state text NOT NULL DEFAULT 'OK' CHECK(reconciliation_state IN ('OK','RECONCILIATION_REQUIRED')),
 concentration_limit_bps integer NOT NULL DEFAULT 6000 CHECK(concentration_limit_bps BETWEEN 1 AND 10000),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(id,user_id)
);
CREATE TABLE portfolio_cash (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), portfolio_id uuid NOT NULL UNIQUE REFERENCES portfolios(id),
 amount_minor bigint NOT NULL DEFAULT 0 CHECK(amount_minor>=0), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE assets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), symbol text NOT NULL UNIQUE, name text NOT NULL,
 type text NOT NULL CHECK(type IN ('STOCK','ETF')), exchange text NOT NULL, currency text NOT NULL CHECK(currency='THB'),
 country text NOT NULL, sector text NOT NULL, industry text NOT NULL, active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO assets(symbol,name,type,exchange,currency,country,sector,industry) VALUES
 ('PAPER-STOCK','Synthetic paper stock (not a listed security)','STOCK','SIMULATION','THB','TH','Technology','Synthetic fixture'),
 ('PAPER-ETF','Synthetic paper ETF (not a listed fund)','ETF','SIMULATION','THB','TH','Diversified','Synthetic fixture');
ALTER TABLE portfolio_holdings ADD COLUMN portfolio_id uuid REFERENCES portfolios(id);
ALTER TABLE portfolio_holdings ADD COLUMN asset_id uuid REFERENCES assets(id);
ALTER TABLE portfolio_holdings ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE portfolio_holdings ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE portfolio_holdings ADD CONSTRAINT portfolio_holding_owner FOREIGN KEY(portfolio_id,user_id) REFERENCES portfolios(id,user_id);
ALTER TABLE portfolio_holdings ADD CONSTRAINT portfolio_holding_amount CHECK(portfolio_id IS NULL OR (asset_id IS NOT NULL AND quantity>=0 AND quantity=round(quantity,6) AND cost_basis_minor>=0));
CREATE UNIQUE INDEX portfolio_owned_asset ON portfolio_holdings(portfolio_id,asset_id) WHERE portfolio_id IS NOT NULL;
CREATE TABLE market_price_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), asset_id uuid NOT NULL REFERENCES assets(id),
 price_minor bigint NOT NULL CHECK(price_minor>0), currency text NOT NULL CHECK(currency='THB'), as_of timestamptz NOT NULL,
 source text NOT NULL, is_delayed boolean NOT NULL, market_status text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX market_price_owner ON market_price_snapshots(user_id,asset_id,created_at DESC);
CREATE TABLE portfolio_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), portfolio_id uuid NOT NULL, user_id uuid NOT NULL,
 type text NOT NULL CHECK(type IN ('FUND','BUY','SELL')), asset_id uuid REFERENCES assets(id), quantity numeric(30,6),
 amount_minor bigint NOT NULL CHECK(amount_minor>0), fee_minor bigint NOT NULL DEFAULT 0 CHECK(fee_minor>=0),
 cost_minor bigint NOT NULL DEFAULT 0 CHECK(cost_minor>=0), realized_pnl_minor bigint NOT NULL DEFAULT 0,
 quote_id uuid REFERENCES market_price_snapshots(id), ledger_transaction_id uuid NOT NULL UNIQUE REFERENCES ledger_transactions(id),
 idempotency_key text NOT NULL, request_hash text NOT NULL, request_id text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(portfolio_id,user_id) REFERENCES portfolios(id,user_id), UNIQUE(user_id,idempotency_key),
 CHECK((type='FUND' AND asset_id IS NULL AND quantity IS NULL) OR (type IN ('BUY','SELL') AND asset_id IS NOT NULL AND quantity>0 AND quote_id IS NOT NULL))
);
CREATE INDEX portfolio_history ON portfolio_transactions(portfolio_id,created_at DESC);
CREATE TABLE portfolio_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), portfolio_id uuid NOT NULL REFERENCES portfolios(id),
 cash_minor bigint NOT NULL, market_value_minor bigint NOT NULL, total_value_minor bigint NOT NULL, cost_basis_minor bigint NOT NULL,
 unrealized_pnl_minor bigint NOT NULL, realized_pnl_minor bigint NOT NULL, funded_minor bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(total_value_minor=cash_minor+market_value_minor)
);
CREATE INDEX portfolio_snapshot_history ON portfolio_snapshots(portfolio_id,created_at);
CREATE TABLE target_allocations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), portfolio_id uuid NOT NULL REFERENCES portfolios(id),
 target text NOT NULL, weight_bps integer NOT NULL CHECK(weight_bps BETWEEN 0 AND 10000),
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(portfolio_id,target)
);
CREATE TABLE watchlists (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL UNIQUE REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE watchlist_assets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),watchlist_id uuid NOT NULL REFERENCES watchlists(id),asset_id uuid NOT NULL REFERENCES assets(id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(watchlist_id,asset_id));
-- Durable test-provider configuration scoped to authenticated test identities.
CREATE TABLE paper_market_controls (user_id uuid NOT NULL REFERENCES users(id),asset_id uuid NOT NULL REFERENCES assets(id),scenario text NOT NULL CHECK(scenario IN ('unchanged','up','down','stale','delayed','unavailable')),updated_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,asset_id));
CREATE TRIGGER portfolio_transaction_immutable BEFORE UPDATE OR DELETE ON portfolio_transactions FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
CREATE TRIGGER portfolio_snapshot_immutable BEFORE UPDATE OR DELETE ON portfolio_snapshots FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
CREATE OR REPLACE FUNCTION check_portfolio_ledger_balance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE total numeric; count_entries integer;
BEGIN
 IF NEW.transaction_type LIKE 'PORTFOLIO_%' OR NEW.transaction_type='TRANSFER_TO_PORTFOLIO' THEN
  SELECT coalesce(sum(CASE WHEN direction='DEBIT' THEN amount_minor ELSE -amount_minor END),0),count(*) INTO total,count_entries FROM ledger_entries WHERE transaction_id=NEW.id;
  IF total<>0 OR count_entries<2 THEN RAISE EXCEPTION 'Unbalanced portfolio ledger'; END IF;
  IF EXISTS(SELECT 1 FROM ledger_entries e JOIN ledger_accounts a ON a.id=e.ledger_account_id WHERE e.transaction_id=NEW.id AND (a.user_id<>NEW.user_id OR a.account_id IS DISTINCT FROM NEW.account_id)) THEN RAISE EXCEPTION 'Ledger ownership mismatch'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE CONSTRAINT TRIGGER portfolio_ledger_balance AFTER INSERT ON ledger_transactions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_portfolio_ledger_balance();
