# Phase 6 — local read-only Financial Copilot

The safety scope authorized on 2026-09-11 is implemented. The original full Phase 6 prompt/acceptance checklist was not present in the workspace or available conversation; full milestone completion must be checked against it when supplied. This document describes the implemented, reviewable scope, not an inferred replacement acceptance specification.

## Authority and data flow

AI = READ / ANALYZE / PROPOSE ONLY. Risk Engine remains the authority. No proposal is an execution authorization and no execution service consumes AI decision records. The only provider is `mock-local` / `deterministic-rules-v1`; it performs bounded local rules, not LLM inference. No external AI request, API key, broker connection, real money or production deployment is involved.

Gateway authenticates the user's normal session, then sends a short-lived HMAC assertion for the `ai-copilot` audience, user, request ID, method, path and exact JSON body. AI never receives the reusable bearer/refresh token. It rejects bearer authentication and invalid/expired/modified assertions. Trading/Risk/Allocation/Portfolio do not accept the AI assertion as authentication. The Gateway ignores user-supplied identity headers and creates its own assertion.

AI Service (local loopback port 3007) uses its own PostgreSQL login. The login inherits only `tipkhun_ai`, is not an owner/superuser/role administrator, and receives no owner database URL. Startup/readiness and each authenticated request fail closed if credential configuration or effective table permissions are unsafe. Credentials and auth tables are not readable. Executable public security-definer routines are rejected. `tool/ai-runtime.mjs` provisions an ephemeral local login and passes an allowlist of environment variables to the AI process; shutdown drops that login. A configured owner/admin database connection is needed by the local launcher to provision roles, never by the AI child.

The role can SELECT explicitly listed financial tables and INSERT/SELECT `ai_decisions` and `ai_audit_records`. It cannot INSERT/UPDATE/DELETE/TRUNCATE financial tables or mutate existing AI history. RLS scopes AI history to the authenticated request owner and disallows strategy/risk authorization fields on AI inserts. Decision plus audit insert commit atomically. Raw questions, tokens and credentials are not stored in AI history.

Financial reads are parameterized and owner-scoped in the trusted context adapter. Financial-table tenant isolation is enforced by this adapter, not financial-table RLS; PostgreSQL RLS is currently limited to AI history. The model/provider receives only data and has **zero callable tools**, database handles, HTTP clients, execution credentials or dynamic tool dispatcher. This is an application/process-credential boundary; it is not a claim of an OS sandbox against arbitrary malicious code running as the developer's operating-system user.

## Read/write separation

`@tipkhun/financial-read` contains dependency-injected portfolio valuation, fixture market reads and bot status projections. It has no runtime dependency on execution services, auth or the owner DB pool. Portfolio Service and AI Service reuse the same valuation and market arithmetic. AI context and portfolio/bot projection reads run in `REPEATABLE READ READ ONLY` transactions. Empty users stay empty; reads do not initialize portfolios/accounts/ledger buckets.

- `GET /portfolio`, `/holdings`, `/cash`, `/targets`, `/performance`, `/orders` and `/funding-history` never capture snapshots or reconcile. Performance returns existing observed snapshots only.
- `POST /portfolio/snapshots` explicitly captures one observed snapshot, under the owner lock, with reconciliation checks and an audit event. The Portfolio UI offers **Record snapshot**. Repeated POSTs are separate requested observations; automatic GET/reload has no write effect.
- `POST /portfolio/reconcile` explicitly checks/latches a mismatch; it never silently repairs balances. Existing execution-time checks remain on funding/order operations.
- `GET /bot/status` and the Trading Service's `GET /reconciliation` read stored status only. `POST /reconcile`, startup recovery and the existing monitoring worker own reconciliation mutations.
- Bot/portfolio status returned by reads is the last stored reconciliation result, not a new verification. Portfolio includes `reconciliationVerified: false`.

A concurrent explicit execution/worker can independently change state while AI reads. The UNKNOWN-order regression test holds the owner lock to exclude workers and prove the read itself does not recover broker evidence; releasing the lock and explicitly reconciling proves the write operation still works.

## API and UI

All public paths below are under `/api/v1`, authenticated by Gateway:

| Method/path | Behavior | Writes |
| --- | --- | --- |
| GET `/copilot/context` | Server portfolio valuation, stored bot state, plan/profile, ledger buckets, recent allocations, watchlist, timestamp and provenance | None |
| POST `/copilot/query` | Strict `{ "question": "...", "copilotMode"?: "..." }`, 1–2000 characters; deterministic analysis, missing-data warnings, concentration/target review proposals | One AI decision + AI audit |
| GET `/copilot/decisions` | Latest 50 owned analysis records | None |

Unknown financial/context/user/tool fields are rejected; there is no `/copilot/execute` or generic tool endpoint. The provider cannot execute regardless of prompt wording. The refusal keyword detector is a UI explanation only, not the enforcement boundary.

React `/assistant` shows sourced facts, timestamp, mock/fixture labels, limitations, review proposals and persisted analysis history. It has no execution/approve-trade button. Source paths refer to fields in `/copilot/context`, not permission to invoke financial writes. Missing plans and unavailable/stale prices are explicit. Portfolio valuation is `null` when its market data is unavailable, rather than fabricating a current value. Risk plan limits are descriptive, not a newly computed RiskDecision or available trading budget.

Flutter's existing local assistant remains unchanged. Native remote Copilot UI, arbitrary investment research, real LLMs, full strategy/backtest analysis and any unprovided Phase 6 requirements are not claimed as implemented.

## Local validation

Run migrations with `pnpm db:migrate`, then `pnpm dev` for the local runtime. PostgreSQL must permit the development launcher to create/drop its temporary restricted role. `pnpm dev` builds before launch; if the restricted role cannot be provisioned or isolation checks fail, AI does not start. No privileged credential fallback exists. Compose's existing service profile does not launch AI; use the local launcher for this milestone.

`pnpm test:integration` requires the dedicated `_test` database and runs Phase 2, Paper/ledger/allocation, Portfolio, then AI tests. It provisions and removes a separate AI login without resetting records. `pnpm test:browser` runs the real React Copilot flow and existing browser/shared Flutter backend flows. Exact final evidence is in PROGRESS.md.

## 2026-09-13 continuation

Context includes owner-scoped `trading.totalTrades`, `trading.netPnlMinor`, and `profit.totalMinor` from full persisted history, using string counts/amounts. Category freshness remains unavailable and is disclosed. Query now validates provider output before saving and applies a five-second deadline to health/generation. Optional copilotMode accepts the six labels in output.ts; all still use the same deterministic summary, so specialized reviews are not complete. Build/lint/unit checks pass; the added database checks await a reachable test database. See PHASE6_ACCEPTANCE_AUDIT.md for current evidence and remaining work.
# Phase 6 acceptance result — COMPLETED — 2026-09-13

The complete user-provided acceptance passed: six modes, freshness/explainability, structured provider failures, server PostgreSQL context, immutable history, React backend flow, Flutter RemoteAIRepository shared history, owner/DB isolation, and advisory/refusal E2E. Failed=0; skipped=0.
