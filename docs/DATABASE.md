# PostgreSQL foundation

`database/migrations/001_initial.sql` creates UUID keyed tables for users, risk profiles, immutable plan versions, accounts, trades, idempotent orders, positions, strategies, allocations, holdings, bot sessions, AI decisions and audit logs. Money columns use integer minor units (`bigint`); quantities use `numeric(30,10)`; timestamps use UTC `timestamptz`.

The migration is additive and not connected to the existing Flutter `SharedPreferences` data. No local plan or trade is imported or deleted. Before a remote migration, add an explicit import tool with row counts, checksums, dry run, backup and rollback. `orders(account_id, idempotency_key)` and `profit_allocations(user_id, batch_id)` enforce duplicate protection at the database boundary.

PostgreSQL is not started automatically by tests. `docker compose -f infra/docker-compose.yml up -d postgres redis` starts the local dependencies and applies the SQL from the init directory to a named volume. Never place production credentials in this file; local defaults are development-only.
