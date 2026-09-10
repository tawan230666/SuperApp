# Tipkhun Capital architecture — 2026-09-08

## Verified existing application
Flutter / Dart, shared_preferences, no backend or Git metadata in this working directory. Existing integer-satang journal, fee-aware cumulative-loss risk engine, allocation preview/history, discipline replay, 30-day history, five navigation destinations, and rule-based assistant remain intact. Baseline: 22 tests passed.

## Local paper execution milestone
Dashboard → BotDashboard → PaperEngine → PaperBrokerAdapter → MockBrokerAdapter.

PaperEngine is Dart domain code independent of Flutter. It serializes requests within one instance, persists reservation/submission intent before broker effects, checks deterministic InvestmentPlan rules plus reserved risk, freshness, connectivity, fully funded exposure and one open position. All entry paths use submit. There is no AI execution path or live implementation.

Instrument is explicitly SYNTHETIC-THB, long-only, integer units, integer satang. Buy limit equals the synthetic execution price. Mock close returns the same price; fees and spread are explicitly zero assumptions, not market estimates. Entire notional is reserved to model loss to zero. Profits never increase the original risk budget or funding capacity. Losses use close time, UTC storage and Bangkok accounting days. Existing manual journal still uses device-local days.

Orders have lifecycle states including partial, unknown, closing and terminal outcomes. Unknown submission retains reservation; reconciliation never resends. Ambiguous closing remains unresolved because this minimal adapter cannot prove a close outcome. Emergency latches immediately, prevents new broker calls after pending persistence, reviews pending orders, and retains filled positions for explicit close. A lock does not auto-reset.

Snapshots contain the immutable-by-convention plan version, orders and append-only application event history. Bot state is exposed read-only. Order/event views are defensive copies. Restore pauses rather than resumes; known local synthetic positions are reconstructed. An unknown external outcome is never inferred absent merely because lookup returns null.

## Storage boundary and migration
Existing `tipkhun.plan.v1` and version 1 schema are unchanged. New `tipkhun.paper.synthetic.v1` is separate; no import of paper gains into original profit allocation. Corrupt paper data is surfaced without replacement. Regression verifies original serialized plan, trades, fees and allocations remain unchanged.

This is an additive namespace, not a database migration. SharedPreferences is not a durable transaction database, encrypted vault, multi-process lock or tamper-proof audit ledger. There is no claim of production financial accounting. Disk failure locks execution; uncertain state requires review. Existing journal data is never reset.

## Gaps to target architecture
Plan-version editing, double-entry ledger, allocation batch idempotency across processes, server persistence, authenticated gateway, workers, external broker APIs, AI structured decisions, strategy registry/backtests, sandbox and full reconciliation are pending. The present bot is a manual paper execution harness, not an autonomous strategy scheduler. Adapter covers execution operations only; account/balance/instrument/history contract must expand before external integration.

## Web milestone — 2026-09-09

Native Flutter Router/RouteInformationParser keeps one workspace MaterialPage, preserving plan/chat/paper state across route changes. Hash URLs avoid server deep-link rewrite dependencies. Unknown paths get an explicit not-found page. AppShell shares mobile bottom nav and desktop rail (1024 breakpoint); PanelGrid and ResponsivePageContainer adapt to available width.

PaperSession owns the one local PaperEngine independently of BotDashboard. PaperRepository now isolates SharedPreferences from UI/domain. Future authenticated API adapter must replace execution, not merely replace storage. No broker secrets or critical production worker runs in the browser.

Desktop journal reuses filtered TradeRecord data, with paginated DataTable and CSV preview/copy. CSV quotes fields and neutralizes spreadsheet formula prefixes. Missing legacy fields are not inferred. Chart series are derived from existing net outcomes, explicitly separate from broker equity/market quotes.

Original T artwork was recovered from remote main and restored, replacing previous placeholder. Existing platform icons restored from original history. Prior `assets/brand` generated designs are no longer in Flutter's asset manifest.

## Monorepo foundation — 2026-09-10

The repository now has a pnpm workspace with `apps/web` (React + TypeScript + Vite), a guarded `apps/mobile` migration boundary, `packages/contracts`, `packages/validation`, `packages/shared`, Node/Express service boundaries under `services/`, SQL under `database/migrations`, and local dependencies under `infra/`.

The React app is a new Web client and does not duplicate Flutter business calculations: its empty dashboard explicitly waits for API data. The gateway and risk service use shared runtime schemas. The TypeScript risk gate mirrors the current conservative client rules and is tested independently; it is not yet authoritative for users because auth, persistence and tenant isolation are not enabled.

## Phase 2 implementation — 2026-09-10

React -> Gateway authentication -> owner-scoped risk/plan persistence ->
Risk Service authentication -> DB snapshot -> deterministic planning decision.
`packages/database` owns pg pooling/transactions; `packages/auth` shares the
session and auth route implementation between Auth Service and Gateway;
`packages/risk-data` owns plan/profile queries and authoritative planning checks.
Gateway mounts the shared auth implementation directly (not a network proxy to
Auth Service). All three use the same PostgreSQL database.

Web AuthProvider refreshes a cookie session, loads /me, protects routes, and
connects Dashboard/Risk settings to real API requests. Missing plan shows first
plan onboarding, never a fake financial snapshot. Profile and plan saves are
separate transactions; if the second fails the profile may already be saved.
The UI reports failure and preserves form inputs; cross-resource atomic save is
PARTIAL. Preview includes all proposed fields and a high daily-risk warning.

Flutter keeps its existing local model and storage. New interfaces and remote
adapters live under lib/data/remote with PLATFORM_REPOSITORY=local|remote;
transport and secure token storage are not wired. Default remains local.
Redis is provisioned but not a financial source of truth.

## Phase 3 Paper Trading — implemented

Gateway proxies owned bot/order/position/trade routes to Trading Service. Trading
creates a durable paper account, serializes each user through the owner row lock,
calls the authoritative Risk Service reservation endpoint, and only then invokes
the deterministic PaperBrokerAdapter. PostgreSQL records state transitions,
fills, fees, positions, balances and audit events. Idempotency keys are unique per
account and concurrent reservations serialize against the owner lock.

UNKNOWN outcomes are never retried blindly. They hold their reservation and set
RECONCILIATION_REQUIRED until broker order/fill evidence permits recovery. Startup
recovery scans paper accounts and reconciliation compares broker fills, order
states, positions, cash, fees and realized P&L. Emergency stop and cancellation
share the account lock; explicit position close is separate and emergency stop
never liquidates.

Paper Broker supports deterministic market fill, partial fill continuation,
reject, cancellation, error, unknown outcome and slippage scenarios. No market
feed, live broker, AI override or real-money execution exists.

Phase 2 acceptance update: Gateway proxies /api/v1/auth to Auth Service through
AUTH_SERVICE_URL. Earlier direct shared-router mounting is historical. Both
Gateway/Auth/DB and Gateway/Risk/DB network paths passed integration acceptance.
