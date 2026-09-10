# Staged migration

1. Monorepo foundation: add workspaces, shared contracts, React Web, gateway and service health endpoints. Root Flutter remains in place.
2. Database/Auth: add migrations, password hashing/session persistence, tenant authorization and import verification before replacing local stores.
3. Risk: compare the TypeScript deterministic engine against Flutter fixtures; route both clients through authenticated gateway in shadow/read-only mode first.
4. Trading/Paper: move Paper execution server-side only after reconciliation and idempotent transaction tests. Keep local fallback until migration is proven.
5. Allocation/Portfolio/AI/Quant: migrate one bounded capability at a time with snapshots, audit records and rollback. AI proposals always pass the risk service.

No Big Bang move of Flutter directories is performed in the foundation phase. A future `apps/mobile` move must preserve Android/iOS project paths, assets, package identifiers, tests and the existing `tipkhun.plan.v1` key, then run `flutter analyze`, `flutter test` and native build checks.
