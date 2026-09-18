ALTER TABLE accounts ADD COLUMN cash_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE accounts ADD COLUMN initial_capital_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE accounts ADD COLUMN realized_pnl_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE accounts ADD COLUMN fees_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE accounts ADD COLUMN reconciliation_state text NOT NULL DEFAULT 'OK' CHECK(reconciliation_state IN ('OK','RECONCILIATION_REQUIRED'));
CREATE UNIQUE INDEX accounts_one_paper ON accounts(user_id) WHERE environment='paper';
ALTER TABLE orders ADD COLUMN paper_order boolean NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN quantity bigint NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN filled_quantity bigint NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN price_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN scenario text NOT NULL DEFAULT 'fill';
ALTER TABLE orders ADD COLUMN request_hash text;
ALTER TABLE orders ADD COLUMN approved_at timestamptz;
ALTER TABLE orders ADD COLUMN plan_version_id uuid REFERENCES plan_versions(id);
ALTER TABLE orders ADD COLUMN reject_reason text;
ALTER TABLE orders ADD CONSTRAINT paper_order_quantity CHECK(NOT paper_order OR (quantity>0 AND filled_quantity>=0 AND filled_quantity<=quantity AND price_minor>0));
ALTER TABLE positions ADD COLUMN order_id uuid UNIQUE REFERENCES orders(id);
ALTER TABLE positions ADD COLUMN entry_fees_minor bigint NOT NULL DEFAULT 0;
ALTER TABLE trades ADD COLUMN paper_order_id uuid UNIQUE REFERENCES orders(id);
ALTER TABLE bot_sessions ADD COLUMN last_heartbeat timestamptz;
ALTER TABLE bot_sessions ADD COLUMN strategy_version text NOT NULL DEFAULT 'manual-synthetic-v1';
CREATE UNIQUE INDEX bot_sessions_one_paper ON bot_sessions(account_id);
CREATE TABLE risk_reservations(order_id uuid PRIMARY KEY REFERENCES orders(id),amount_minor bigint NOT NULL CHECK(amount_minor>0),created_at timestamptz NOT NULL DEFAULT now(),released_at timestamptz);
CREATE TABLE order_events(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES orders(id),from_state text,to_state text NOT NULL,reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE paper_broker_accounts(account_id uuid PRIMARY KEY REFERENCES accounts(id),initial_capital_minor bigint NOT NULL CHECK(initial_capital_minor>0));
CREATE TABLE paper_broker_orders(order_id uuid PRIMARY KEY REFERENCES orders(id),state text NOT NULL,filled_quantity bigint NOT NULL DEFAULT 0);
CREATE TABLE paper_broker_fills(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES orders(id),side text NOT NULL CHECK(side IN ('BUY','SELL')),quantity bigint NOT NULL CHECK(quantity>0),price_minor bigint NOT NULL CHECK(price_minor>0),fee_minor bigint NOT NULL CHECK(fee_minor>=0),created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX paper_fills_order ON paper_broker_fills(order_id);
CREATE OR REPLACE FUNCTION validate_paper_order_transition() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NOT NEW.paper_order OR NEW.state=OLD.state THEN RETURN NEW; END IF;
 IF (OLD.state='CREATED' AND NEW.state IN ('RISK_CHECKED','REJECTED')) OR
 (OLD.state='RISK_CHECKED' AND NEW.state IN ('SUBMITTED','REJECTED','CANCELLED')) OR
 (OLD.state='SUBMITTED' AND NEW.state IN ('ACKNOWLEDGED','REJECTED','UNKNOWN')) OR
 (OLD.state='ACKNOWLEDGED' AND NEW.state IN ('PARTIALLY_FILLED','FILLED','REJECTED','CANCELLED','UNKNOWN','EXPIRED')) OR
 (OLD.state='PARTIALLY_FILLED' AND NEW.state IN ('FILLED','CANCELLED','UNKNOWN','EXPIRED')) OR
 (OLD.state='FILLED' AND NEW.state='CLOSED') OR
 (OLD.state IN ('CANCELLED','EXPIRED') AND NEW.state='CLOSED' AND OLD.filled_quantity>0)
 THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid paper order transition: % -> %',OLD.state,NEW.state;
END $$;
CREATE TRIGGER paper_order_transition BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION validate_paper_order_transition();
