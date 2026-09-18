-- Additive hardening: migration 012 remains checksum-identical and applied.
CREATE FUNCTION guard_broker_intent_plan() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW.plan_version_id IS DISTINCT FROM OLD.plan_version_id THEN
  RAISE EXCEPTION 'Immutable broker plan version';
 END IF;
 IF NEW.plan_version_id IS NULL OR NOT EXISTS (
  SELECT 1 FROM plan_versions v JOIN investment_plans p ON p.id=v.plan_id
  WHERE v.id=NEW.plan_version_id AND p.user_id=NEW.user_id
 ) THEN RAISE EXCEPTION 'Broker plan owner mismatch'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER broker_intent_plan BEFORE INSERT OR UPDATE ON broker_orders
 FOR EACH ROW EXECUTE FUNCTION guard_broker_intent_plan();
CREATE TRIGGER broker_intent_no_delete BEFORE DELETE ON broker_orders
 FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();
