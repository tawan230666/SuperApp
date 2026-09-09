# Next steps

1. Finish Phase 1 before external broker integration: versioned plans effective on future accounting days, immutable balanced ledger with idempotent posting, atomic SQLite migration with backup/rollback and legacy fixtures. Keep old journal lock until migration passes regression tests.
2. Move paper engine ownership into account-scoped service with durable transactions and restart recovery. Expand broker snapshots to account equity, fees, instrument metadata, pending/cancel acknowledgments, positions and fills. Add close-outcome reconciliation; unknowns remain locked until proved resolved.
3. Add strategy registry/version hash, approval gates, backtesting and isolated worker; the current manual-synthetic-v1 label is not a strategy library or backtest result.
4. Implement authenticated backend/worker for continuous monitoring, tenant isolation and backups. SharedPreferences is only local prototype storage.
5. Research official paper APIs, supported deployment environment and terms before choosing provider. Credentials and provider selection are needed only for that later integration, not current mock tests.
6. Owner's original T logo required at assets/brand/tipkhun-owner-logo.png or SVG. Replace TC placeholder and all platform launcher assets together after verifying artwork.
7. Finish bot-specific responsive/restart/error tests and physical-device E2E. Tests currently exercise local mock preferences; device restart durability is not proven.
8. Prepare legal/security gates before any real money, personalized investment advice or broker partnership. No live action is authorized by this implementation.
