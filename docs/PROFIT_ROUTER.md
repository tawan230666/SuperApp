# Paper Profit Router

Profit Router consumes only positive realized net profit recorded by closed
Paper trades. Unrealized or open-position P&L is unavailable for allocation,
and an allocation batch is idempotent and locked per user. Default routing is
50% trading capital, 30% long-term reserve and 20% withdrawal reserve; custom
weights must total 10,000 basis points. Integer rounding assigns the remainder
to withdrawal reserve so totals always equal the source amount.

Preview is read-only. Confirm creates one ledger transaction and allocation
batch in the same PostgreSQL transaction. Withdrawal reserve is a planning
bucket, never a withdrawal or cash movement outside the Paper ledger.

The acceptance flow verifies 50/30/20 routing, 101-minor-unit remainder
rounding, preview side-effect freedom, concurrent confirmation locking,
idempotent retries, owner isolation and shared backend reads from Flutter's
remote repository.

## Portfolio funding consumer

Long-term allocations remain reserves until an explicit, idempotent, atomic TRANSFER_TO_PORTFOLIO posts to the ledger. Funding cannot exceed the credit-net LONG_TERM_RESERVE balance. Allocation available uses the remaining REALIZED_PROFIT credit-net balance directly: allocation debits already consumed profit, so batch history must not be subtracted a second time. Historical realized trading P&L remains in trades. Portfolio realized P&L is a separate bucket and is not automatically routed again.
