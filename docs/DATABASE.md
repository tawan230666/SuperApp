# PostgreSQL foundation

`database/migrations/001_initial.sql` creates UUID keyed tables for users, risk profiles, immutable plan versions, accounts, trades, idempotent orders, positions, strategies, allocations, holdings, bot sessions, AI decisions and audit logs. Money columns use integer minor units (`bigint`); quantities use `numeric(30,10)`; timestamps use UTC `timestamptz`.

The migration is additive and not connected to the existing Flutter `SharedPreferences` data. No local plan or trade is imported or deleted. Before a remote migration, add an explicit import tool with row counts, checksums, dry run, backup and rollback. `orders(account_id, idempotency_key)` and `profit_allocations(user_id, batch_id)` enforce duplicate protection at the database boundary.

PostgreSQL is not started automatically by tests. `docker compose -f infra/docker-compose.yml up -d postgres redis` starts the local dependencies and applies the SQL from the init directory to a named volume. Never place production credentials in this file; local defaults are development-only.

## Phase 2 — persistence implementation (2026-09-10)

`packages/database` uses node-postgres (`pg`) rather than an ORM to retain the
existing SQL migration foundation. Its pool and single-client transactions are
explicit; int8 values remain decimal strings. See the official
[pooling](https://node-postgres.com/features/pooling),
[transactions](https://node-postgres.com/features/transactions), and
[type handling](https://node-postgres.com/features/types) documentation.

- Pool: max 10 connections/process, 3-second connection timeout, 10-second SQL
  timeout, UTC sessions. Production pool sizing is not configured.
- Money: PostgreSQL bigint, JSON decimal strings, server BigInt arithmetic.
  Legacy local engine contracts are preserved separately.
- `pnpm db:migrate`: checks connectivity, obtains a transaction advisory lock,
  checks SHA-256 checksums, and applies pending SQL plus migration metadata in
  one transaction. Failures roll back; there is no reset/drop command.
- `pnpm db:status`: reports applied/pending migrations (initializes the metadata
  table if missing). Do not edit an applied migration.
- Existing Docker-bootstrap schemas can be adopted by migration 001's existing
  IF NOT EXISTS statements. Conflicting old data (duplicate normalized emails or
  multiple profiles/plans per owner) causes migration failure; no data is deleted.
- Migration 002 adds normalized email uniqueness and token/session persistence.
- Migration 003 adds risk settings and immutable PlanVersion history. A trigger
  rejects UPDATE/DELETE; plan writes serialize on the owner row.
- UUID primary keys; timestamptz dates; database role remains an application role.
  Ownership is enforced in parameterized application queries, not PostgreSQL RLS.
- `pnpm db:seed` requires NODE_ENV=development/test plus explicitly supplied
  SEED_EMAIL and SEED_PASSWORD (shared credential validation). It atomically
  creates a hashed-password user, simulation account and audit. Repeating it
  preserves existing credentials/data. No fake balance or plan is seeded.


Validation status: SQL runner and persistence code are implemented; Phase 2
PostgreSQL acceptance is complete. Phase 3 migrations 004/005 and Paper Trading
transactions are applied and verified by the real Paper integration suite.

Migration 004 adds paper account balances, broker order/fill records, order event
history, reservation records, bot heartbeat/state and a database transition
trigger. Migration 005 adds evidence-backed UNKNOWN recovery transitions. Account
cash, fees, positions, fills and realized P&L are mutated in a transaction; the
reconciliation function compares the persisted ledger against broker evidence.
No destructive reset or volume deletion is used.
