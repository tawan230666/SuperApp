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
