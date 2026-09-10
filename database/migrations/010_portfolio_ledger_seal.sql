-- Seal the entry set when its creating transaction commits. A correction must
-- create a new header; balanced entries cannot be appended to historical headers.
ALTER TABLE ledger_transactions ADD COLUMN created_in_xact bigint NOT NULL DEFAULT txid_current();
CREATE OR REPLACE FUNCTION reject_sealed_portfolio_entry() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE header ledger_transactions%ROWTYPE;
BEGIN
 SELECT * INTO header FROM ledger_transactions WHERE id=NEW.transaction_id;
 IF (header.transaction_type LIKE 'PORTFOLIO_%' OR header.transaction_type='TRANSFER_TO_PORTFOLIO') AND header.created_in_xact<>txid_current() THEN
  RAISE EXCEPTION 'Portfolio ledger transaction is sealed; use a new reversal transaction';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER portfolio_entry_sealed BEFORE INSERT ON ledger_entries FOR EACH ROW EXECUTE FUNCTION reject_sealed_portfolio_entry();
