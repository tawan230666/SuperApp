# AI Safety — Phase 6

Phase 6 Copilot is READ / ANALYZE / PROPOSE ONLY. Risk Engine remains the authority. The provider has no execution tools, broker credentials, database handles, network client, or dynamic tool dispatcher. There is no `/copilot/execute` route.

The Gateway authenticates the user, then sends AI a short-lived HMAC assertion bound to the user, request ID, method, path, and exact body. User bearer tokens, cookies, and identity headers are not forwarded. The AI service rejects bearer authentication, expired or modified assertions, and unsafe role configuration.

The AI database login can SELECT the explicitly listed financial tables and append owned AI decision/audit records. It cannot write, update, delete, truncate, own, or escalate financial tables; it cannot read users or auth credentials. PostgreSQL RLS scopes AI history to the asserted owner, and immutable triggers reject changes to recorded AI history.

Financial context reads run in owner-scoped `REPEATABLE READ READ ONLY` transactions. GET/context and GET/status paths do not capture snapshots, reconcile, create accounts, submit orders, change risk, write ledger entries, allocate profit, fund portfolios, or buy/sell holdings. Explicit financial operations remain separate and authoritative.

Provider health, timeout, malformed-output, unavailable-provider, provenance, mode, and structured schema checks fail closed before a decision is persisted. Synthetic fixture prices and stale/delayed/unavailable data are disclosed. Prompt injection is treated as data; execution-shaped requests produce a refusal and leave financial rows unchanged.

External or paid AI, real brokers, live trading, real money, strategy generation, autonomous agents, and production deployment remain locked.
