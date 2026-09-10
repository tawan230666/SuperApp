-- Preserve original portfolio ledger headers as well as their immutable entries.
CREATE TRIGGER portfolio_ledger_header_immutable BEFORE UPDATE OR DELETE ON ledger_transactions
 FOR EACH ROW WHEN (OLD.transaction_type LIKE 'PORTFOLIO_%' OR OLD.transaction_type='TRANSFER_TO_PORTFOLIO')
 EXECUTE FUNCTION reject_ledger_mutation();
-- Validate portfolio ledger balance/ownership again if entries are appended.
CREATE OR REPLACE FUNCTION check_portfolio_entry_balance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE header ledger_transactions%ROWTYPE; total numeric;
BEGIN
 SELECT * INTO header FROM ledger_transactions WHERE id=NEW.transaction_id;
 IF header.transaction_type LIKE 'PORTFOLIO_%' OR header.transaction_type='TRANSFER_TO_PORTFOLIO' THEN
  SELECT coalesce(sum(CASE WHEN direction='DEBIT' THEN amount_minor ELSE -amount_minor END),0) INTO total FROM ledger_entries WHERE transaction_id=header.id;
  IF total<>0 THEN RAISE EXCEPTION 'Unbalanced portfolio ledger'; END IF;
  IF EXISTS(SELECT 1 FROM ledger_entries e JOIN ledger_accounts a ON a.id=e.ledger_account_id WHERE e.transaction_id=header.id AND (a.user_id<>header.user_id OR a.account_id IS DISTINCT FROM header.account_id)) THEN RAISE EXCEPTION 'Ledger ownership mismatch'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE CONSTRAINT TRIGGER portfolio_entry_balance AFTER INSERT ON ledger_entries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_portfolio_entry_balance();
