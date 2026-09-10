# Paper Ledger

Phase 4 adds immutable double-entry ledger tables. Every paper account has
`PAPER_CASH`, `TRADING_CAPITAL`, `REALIZED_PROFIT`, `FEES`,
`LONG_TERM_RESERVE`, and `WITHDRAWAL_RESERVE` buckets. Transactions are UUID,
UTC timestamped, owner scoped and idempotent; debit and credit totals must
balance. Entries cannot be updated or deleted. Corrections use a new reversal
transaction. Ledger summaries and transactions are exposed through the
authenticated API.

All values are integer minor currency units. The ledger is Paper/Simulation
only and is reconciled against persisted paper fills, positions and trades.
