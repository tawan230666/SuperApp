-- AI uses a separate login inheriting ONLY this non-owning role. No service credentials.
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='tipkhun_ai') THEN
  CREATE ROLE tipkhun_ai NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
 END IF;
END $$;
GRANT USAGE ON SCHEMA public TO tipkhun_ai;
GRANT SELECT ON risk_profiles,investment_plans,plan_versions,accounts,orders,positions,trades,
 bot_sessions,risk_reservations,ledger_accounts,ledger_entries,ledger_transactions,
 allocation_settings,allocation_batches,profit_allocations,portfolios,portfolio_cash,
 portfolio_holdings,portfolio_transactions,portfolio_snapshots,target_allocations,assets,
 market_price_snapshots,paper_market_controls,watchlists,watchlist_assets TO tipkhun_ai;
CREATE TABLE ai_audit_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL REFERENCES users(id),
 decision_id uuid NOT NULL REFERENCES ai_decisions(id),request_id uuid NOT NULL,
 action text NOT NULL CHECK(action='AI_PROPOSAL_RECORDED'),created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT,INSERT ON ai_decisions,ai_audit_records TO tipkhun_ai;
CREATE TRIGGER ai_decision_immutable BEFORE UPDATE OR DELETE ON ai_decisions FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
CREATE TRIGGER ai_audit_immutable BEFORE UPDATE OR DELETE ON ai_audit_records FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
-- Restricted login can append only its authenticated request owner's records.
ALTER TABLE ai_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_audit_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY ai_decisions_owner ON ai_decisions TO tipkhun_ai USING(user_id=nullif(current_setting('app.ai_user_id',true),'')::uuid) WITH CHECK(user_id=nullif(current_setting('app.ai_user_id',true),'')::uuid AND agent_type='mock-copilot-v1' AND risk_check IS NULL AND strategy_version_id IS NULL);
CREATE POLICY ai_audit_owner ON ai_audit_records TO tipkhun_ai USING(user_id=nullif(current_setting('app.ai_user_id',true),'')::uuid) WITH CHECK(user_id=nullif(current_setting('app.ai_user_id',true),'')::uuid AND EXISTS(SELECT 1 FROM ai_decisions d WHERE d.id=decision_id AND d.user_id=ai_audit_records.user_id));
-- Other services retain their existing access; the AI role is never a member of them.
