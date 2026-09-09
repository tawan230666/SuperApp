# Decisions — 2026-09-08

1. Preserve existing financial models and journal key, with additive paper namespace. Keep historical plan lock until versioned migration is implemented. Paper captures a plan snapshot; existing trades are not treated as paper fills.
2. Use dependency-free Dart execution domain first. Do not add Python/PostgreSQL/Redis before implementing durable server requirements. No background service is claimed.
3. Local synthetic paper adapter requires no credentials, network, market-data purchase or broker selection. Official provider feasibility review is deferred; no claim about MT5, IQ Option or Thai permissions has been made.
4. Accept only PaperBrokerAdapter with the synthetic environment identifier. Live interface has no implementation or factory, and there is no Boolean live toggle.
5. Conservative paper risk: full notional, no short selling/leverage, one open position. Existing plan figures are simulation inputs, not approved live policy. A production default risk policy remains undecided.
6. Uncertain submission/close and persistence failure fail closed. Emergency retains positions for review rather than promising liquidation. Locked sessions cannot automatically restart.
7. Existing brand asset and painter are a generated C, not the owner's requested T. In-app painter now shows a neutral TC text placeholder. Need owner-provided `assets/brand/tipkhun-owner-logo.png` (or original SVG) before final branding. Existing packaged launcher icons still need replacement after the original is supplied; no new logo was invented.
8. No Git repository exists locally. Checkpoint copied to `/private/tmp/tipkhun-baseline-20260908`. Nothing pushed/published. To reconnect safely: clone the existing remote into a separate private checkout, inspect its history and visibility, compare this workspace, then import reviewed code on a branch. Do not initialize and force-push over existing history. Temporary checkpoint is not a durable backup.
