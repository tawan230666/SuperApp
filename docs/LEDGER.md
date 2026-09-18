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

Realized P&L is `exit proceeds - entry cost - entry fees - exit fees`. The
deterministic test adapter supports profitable, loss and fee-only exits; normal
production configuration exposes no client-controlled exit price. Allocation
rounding floors short-term and long-term shares and assigns the exact remainder
to withdrawal reserve, so the buckets always sum to the source minor amount.

## Portfolio extension

PORTFOLIO_CASH/COST use the existing credit-positive reserve convention. TRANSFER_TO_PORTFOLIO debits LONG_TERM_RESERVE and credits PORTFOLIO_CASH. BUY converts cash into capitalized holding cost. SELL converts disposed average cost into net proceeds and a balancing PORTFOLIO_PNL entry; reported net profit is negative credit-net PORTFOLIO_PNL. Entry fees are capitalized and exit fees reduce proceeds; no duplicate FEES posting. See PORTFOLIO.md for exact equations, rounding, custody-versus-spendable cash and reversal policy.
