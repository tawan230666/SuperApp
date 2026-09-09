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
