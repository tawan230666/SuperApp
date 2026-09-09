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
