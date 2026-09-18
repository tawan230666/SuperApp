-- Non-custodial sandbox mirrors. No cash movement into the Tipkhun ledger.
CREATE TABLE broker_connections (
 id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES users(id),
 provider text NOT NULL CHECK(provider IN ('mock','deterministic-sandbox')),
 mode text NOT NULL DEFAULT 'SANDBOX' CHECK(mode='SANDBOX'),
 status text NOT NULL CHECK(status IN ('CONNECTED','DISCONNECTED')),
 external_account_id text NOT NULL UNIQUE, credential_ref uuid NOT NULL,
 emergency_stop boolean NOT NULL DEFAULT false,
 reconciliation_state text NOT NULL DEFAULT 'OK' CHECK(reconciliation_state IN ('OK','RECONCILIATION_REQUIRED')),
 initial_cash_minor bigint NOT NULL CHECK(initial_cash_minor>0),
 cash_minor bigint NOT NULL CHECK(cash_minor>=0), positions jsonb NOT NULL DEFAULT '[]',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,provider), UNIQUE(id,user_id), CHECK(jsonb_typeof(positions)='array')
);
CREATE TABLE broker_credentials (
 id uuid PRIMARY KEY, connection_id uuid NOT NULL, user_id uuid NOT NULL,
 key_id text NOT NULL, ciphertext text NOT NULL, nonce text NOT NULL, tag text NOT NULL,
 revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(connection_id,user_id) REFERENCES broker_connections(id,user_id)
);
CREATE TABLE broker_orders (
 id uuid PRIMARY KEY, connection_id uuid NOT NULL, user_id uuid NOT NULL,
 idempotency_key text NOT NULL, request_hash text NOT NULL,
 mode text NOT NULL DEFAULT 'SANDBOX' CHECK(mode='SANDBOX'),
 symbol text NOT NULL CHECK(symbol IN ('PTT','TDEX')), side text NOT NULL CHECK(side IN ('BUY','SELL')),
 quantity bigint NOT NULL CHECK(quantity>0), order_type text NOT NULL CHECK(order_type='MARKET'),
 price_minor bigint NOT NULL CHECK(price_minor>0), fee_minor bigint NOT NULL CHECK(fee_minor>=0),
 filled_quantity bigint NOT NULL DEFAULT 0 CHECK(filled_quantity>=0 AND filled_quantity<=quantity),
 state text NOT NULL CHECK(state IN ('CREATED','RISK_CHECKED','AWAITING_CONFIRMATION','SUBMITTING','ACKNOWLEDGED','PARTIALLY_FILLED','FILLED','CANCEL_PENDING','CANCELLED','REJECTED','UNKNOWN','ERROR')),
 preview_hash text NOT NULL, quote_as_of timestamptz NOT NULL, expires_at timestamptz NOT NULL,
 plan_version_id uuid REFERENCES plan_versions(id), risk_reserved_minor bigint NOT NULL DEFAULT 0 CHECK(risk_reserved_minor>=0),
 confirmed_at timestamptz, reason text, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,idempotency_key), UNIQUE(id,connection_id,user_id),
 FOREIGN KEY(connection_id,user_id) REFERENCES broker_connections(id,user_id),
 CHECK(state NOT IN ('SUBMITTING','ACKNOWLEDGED','PARTIALLY_FILLED','FILLED','CANCEL_PENDING','UNKNOWN') OR confirmed_at IS NOT NULL)
);
CREATE FUNCTION validate_broker_order_transition() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'CREATED' OR NEW.confirmed_at IS NOT NULL OR NEW.risk_reserved_minor<>0 OR NEW.filled_quantity<>0 THEN RAISE EXCEPTION 'Broker intent must start CREATED'; END IF;
  RETURN NEW;
 END IF;
 IF (NEW.id,NEW.connection_id,NEW.user_id,NEW.symbol,NEW.side,NEW.quantity,NEW.order_type,NEW.price_minor,NEW.fee_minor,NEW.preview_hash,NEW.request_hash,NEW.idempotency_key,NEW.quote_as_of,NEW.expires_at,NEW.mode)
 IS DISTINCT FROM (OLD.id,OLD.connection_id,OLD.user_id,OLD.symbol,OLD.side,OLD.quantity,OLD.order_type,OLD.price_minor,OLD.fee_minor,OLD.preview_hash,OLD.request_hash,OLD.idempotency_key,OLD.quote_as_of,OLD.expires_at,OLD.mode)
 THEN RAISE EXCEPTION 'Immutable broker intent'; END IF;
 IF NEW.filled_quantity<OLD.filled_quantity THEN RAISE EXCEPTION 'Broker fill regression'; END IF;
 IF OLD.confirmed_at IS NOT NULL AND NEW.confirmed_at IS DISTINCT FROM OLD.confirmed_at THEN RAISE EXCEPTION 'Immutable broker confirmation'; END IF;
 IF NEW.state=OLD.state THEN RETURN NEW; END IF;
 IF (OLD.state='CREATED' AND NEW.state IN ('RISK_CHECKED','REJECTED')) OR
 (OLD.state='RISK_CHECKED' AND NEW.state='AWAITING_CONFIRMATION') OR
 (OLD.state='AWAITING_CONFIRMATION' AND NEW.state IN ('SUBMITTING','REJECTED','CANCELLED')) OR
 (OLD.state='SUBMITTING' AND NEW.state IN ('ACKNOWLEDGED','PARTIALLY_FILLED','FILLED','UNKNOWN','REJECTED','CANCELLED')) OR
 (OLD.state='ACKNOWLEDGED' AND NEW.state IN ('PARTIALLY_FILLED','FILLED','CANCEL_PENDING','REJECTED','UNKNOWN','CANCELLED')) OR
 (OLD.state='PARTIALLY_FILLED' AND NEW.state IN ('FILLED','CANCEL_PENDING','CANCELLED','UNKNOWN')) OR
 (OLD.state='CANCEL_PENDING' AND NEW.state IN ('CANCELLED','PARTIALLY_FILLED','FILLED','UNKNOWN')) OR
 (OLD.state='UNKNOWN' AND NEW.state IN ('ACKNOWLEDGED','PARTIALLY_FILLED','FILLED','REJECTED','CANCELLED')) OR
 (OLD.state='CANCELLED' AND NEW.state='FILLED' AND NEW.filled_quantity>OLD.filled_quantity)
 THEN RETURN NEW; END IF;
 RAISE EXCEPTION 'Invalid broker transition: % -> %',OLD.state,NEW.state;
END $$;
CREATE TRIGGER broker_order_transition BEFORE INSERT OR UPDATE ON broker_orders FOR EACH ROW EXECUTE FUNCTION validate_broker_order_transition();
CREATE TABLE broker_fills (
 id uuid PRIMARY KEY, connection_id uuid NOT NULL, user_id uuid NOT NULL, order_id uuid NOT NULL,
 external_fill_id uuid NOT NULL, sequence bigint NOT NULL CHECK(sequence>0),
 symbol text NOT NULL, side text NOT NULL CHECK(side IN ('BUY','SELL')), quantity bigint NOT NULL CHECK(quantity>0),
 price_minor bigint NOT NULL CHECK(price_minor>0), fee_minor bigint NOT NULL CHECK(fee_minor>=0),
 realized_pnl_minor bigint NOT NULL, executed_at timestamptz NOT NULL,
 UNIQUE(connection_id,external_fill_id), UNIQUE(connection_id,sequence),
 FOREIGN KEY(order_id,connection_id,user_id) REFERENCES broker_orders(id,connection_id,user_id)
);
CREATE TABLE broker_operations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id),
 kind text NOT NULL, idempotency_key text NOT NULL, request_hash text NOT NULL, result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(user_id,kind,idempotency_key)
);
CREATE TABLE broker_order_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), connection_id uuid NOT NULL, user_id uuid NOT NULL,
 external_event_id uuid NOT NULL, payload_hash text NOT NULL, metadata jsonb NOT NULL, outcome text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(connection_id,external_event_id),
 FOREIGN KEY(connection_id,user_id) REFERENCES broker_connections(id,user_id)
);
CREATE TABLE broker_reconciliation_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), connection_id uuid NOT NULL, user_id uuid NOT NULL,
 status text NOT NULL, mismatches jsonb NOT NULL, snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(connection_id,user_id) REFERENCES broker_connections(id,user_id)
);
CREATE TABLE broker_execution_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id),
 action text NOT NULL, entity_id uuid NOT NULL, request_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
-- Persisted simulator represents external broker truth; not Tipkhun mirror tables.
CREATE TABLE sandbox_broker_accounts (
 id uuid PRIMARY KEY, initial_cash_minor bigint NOT NULL CHECK(initial_cash_minor>0),
 connected boolean NOT NULL DEFAULT true, next_sequence bigint NOT NULL DEFAULT 1,
 scenario text NOT NULL DEFAULT 'fill' CHECK(scenario IN ('fill','partial','ack','reject','ack-timeout','network-timeout','stale','unavailable','cancel-timeout'))
);
CREATE TABLE sandbox_broker_orders (
 id uuid PRIMARY KEY, account_id uuid NOT NULL REFERENCES sandbox_broker_accounts(id),
 request_hash text NOT NULL, symbol text NOT NULL, side text NOT NULL, quantity bigint NOT NULL CHECK(quantity>0),
 price_minor bigint NOT NULL CHECK(price_minor>0), state text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE sandbox_broker_fills (
 id uuid PRIMARY KEY, account_id uuid NOT NULL REFERENCES sandbox_broker_accounts(id), order_id uuid NOT NULL REFERENCES sandbox_broker_orders(id),
 sequence bigint NOT NULL CHECK(sequence>0), symbol text NOT NULL, side text NOT NULL,
 quantity bigint NOT NULL CHECK(quantity>0), price_minor bigint NOT NULL CHECK(price_minor>0), fee_minor bigint NOT NULL CHECK(fee_minor>=0),
 realized_pnl_minor bigint NOT NULL, executed_at timestamptz NOT NULL DEFAULT now(), UNIQUE(account_id,sequence)
);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['broker_fills','broker_operations','broker_order_events','broker_reconciliation_runs','broker_execution_audit','sandbox_broker_fills'] LOOP
  EXECUTE format('CREATE TRIGGER immutable_record BEFORE UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation()',t);
 END LOOP;
 -- Explicit denial protects the Phase 6 role even if defaults change in future.
 FOREACH t IN ARRAY ARRAY['broker_connections','broker_credentials','broker_orders','broker_fills','broker_operations','broker_order_events','broker_reconciliation_runs','broker_execution_audit','sandbox_broker_accounts','sandbox_broker_orders','sandbox_broker_fills'] LOOP
  EXECUTE format('REVOKE ALL ON %I FROM tipkhun_ai, PUBLIC',t);
 END LOOP;
END $$;
