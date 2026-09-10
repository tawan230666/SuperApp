# Next steps

1. Finish Phase 1 before external broker integration: versioned plans effective on future accounting days, immutable balanced ledger with idempotent posting, atomic SQLite migration with backup/rollback and legacy fixtures. Keep old journal lock until migration passes regression tests.
2. Move paper engine ownership into account-scoped service with durable transactions and restart recovery. Expand broker snapshots to account equity, fees, instrument metadata, pending/cancel acknowledgments, positions and fills. Add close-outcome reconciliation; unknowns remain locked until proved resolved.
3. Add strategy registry/version hash, approval gates, backtesting and isolated worker; the current manual-synthetic-v1 label is not a strategy library or backtest result.
4. Implement authenticated backend/worker for continuous monitoring, tenant isolation and backups. SharedPreferences is only local prototype storage.
5. Research official paper APIs, supported deployment environment and terms before choosing provider. Credentials and provider selection are needed only for that later integration, not current mock tests.
6. Resolved 2026-09-09: original T logo and platform icons recovered from GitHub. Keep assets/tipkhun-logo.png as source artwork.
7. Finish bot-specific responsive/restart/error tests and physical-device E2E. Tests currently exercise local mock preferences; device restart durability is not proven.
8. Prepare legal/security gates before any real money, personalized investment advice or broker partnership. No live action is authorized by this implementation.


## Web continuation (2026-09-09)

1. Run real Chrome smoke checklist in WEB_DEPLOYMENT.md: hash deep links, refresh/back/forward, journal persistence, CSV clipboard, emergency dialog and all widths. Chrome could not launch in the managed session; widget/render tests do not replace browser E2E.
2. Reconnect root Git metadata using GIT_WORKFLOW.md from a terminal allowed to write .git; feature/web-platform is the durable source on GitHub. Review before main merge.
3. Add durable backend/account API, versioned plans and ledger before extending client mock to external paper APIs. Implement multi-tab coordination or make the backend the sole executor.
4. Select hosting after owner approval; no production deploy, domain or billing is configured. Free-tier terms must be rechecked at release.

## Immediate next milestone: finish Phase 2 acceptance

1. Make a dedicated PostgreSQL test database reachable (Docker Desktop in a
   normal user environment, or provide TEST_DATABASE_URL for an existing test
   instance). Never reset existing data. Run migrations twice and the 27-case
   `pnpm test:integration` suite; fix any failures before claiming acceptance.
2. Verify the real React browser flow: register/login, profile, first plan,
   snapshot/check, next plan version and logout/reload, including HttpOnly cookie
   rotation. Existing component tests mock HTTP and cannot prove this flow.
3. Verify Docker image build and all dependency readiness failures. Add CI with
   PostgreSQL services so DB tests cannot be silently omitted from acceptance.
4. Add atomic profile+plan save and cross-tab refresh coordination; wire Flutter
   transport/OS secure storage only behind the existing local/remote boundary.
5. For the later remote Paper milestone, design authoritative transactional
   order reservation, idempotency and settlement. Current RiskDecision explicitly
   cannot authorize execution and remote trades/positions are not being ingested.

Live trading, real-money brokers, production AI, payment/withdrawal and production
deployment remain LOCKED. Do not advance to them to bypass Phase 2 validation.

## Phase 3 — completed 2026-09-10

Server-side Paper Trading core is implemented and integration verified (20 cases).
Real `/bot` browser acceptance, Docker service readiness, lint/build and the full
Phase 2 + Phase 3 integration suites passed. Remaining work is execution
hardening: richer order/position UX, configurable broker policy, and Flutter HTTP
transport with mobile secure storage. Live trading remains LOCKED.

## Phase 4 — current implementation

Immutable Paper ledger, reserve buckets, allocation settings/confirm APIs,
notifications and stale-bot monitoring are implemented. Complete the dedicated
ledger/allocation integration flow, richer order/position screens and Flutter
remote transport coverage before marking Phase 4 complete.

## Phase 2 acceptance closed — next: Phase 3 Paper Trading

The earlier blocker is resolved. PostgreSQL integration and real React browser
acceptance passed on 2026-09-10. `pnpm test` now includes DB tests and fails if the
test DB is unavailable. Proceed with atomic reservations, idempotent durable
paper orders, reconciliation, emergency-stop races and remote bot UI.
