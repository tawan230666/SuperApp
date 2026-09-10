# Local development

This repository now contains the Flutter app plus a TypeScript monorepo foundation. Flutter remains at the repository root during a safe, staged migration; moving it to `apps/mobile` is deferred until Android/iOS configuration is copied and verified.

```sh
pnpm install
pnpm --filter @tipkhun/contracts test
pnpm --filter @tipkhun/risk-service test
pnpm --filter @tipkhun/api-gateway test
pnpm --filter @tipkhun/web test
pnpm --filter @tipkhun/web dev       # http://localhost:5173
pnpm --filter @tipkhun/risk-service dev # http://localhost:3001
pnpm --filter @tipkhun/api-gateway dev  # http://localhost:3000
docker compose -f infra/docker-compose.yml up -d postgres redis
```

`pnpm build` builds TypeScript packages and services; `pnpm test` runs package tests. Use the existing Flutter commands for Mobile and the legacy Flutter Web target while the React app becomes the primary Web target.

Docker service containers are behind the `services` profile until a lockfile and production image review are complete:

```sh
docker compose -f infra/docker-compose.yml --profile services up --build
```

No command here deploys, spends money, creates users, connects a broker or enables Live Trading.

## Phase 2 local setup

Requires Node 24, pnpm as pinned by packageManager, running Docker Desktop.

```sh
pnpm install
cp .env.example .env
docker compose -f infra/docker-compose.yml up -d postgres redis
pnpm db:status
pnpm db:migrate
pnpm db:status
pnpm dev
```

`pnpm dev` builds workspace dependencies and starts React :5173, Gateway :3000,
Risk :3001, Auth :3002. Root wrappers load .env. Register through React; no default
user or balance is seeded automatically. Optional `pnpm db:seed` requires
SEED_EMAIL and SEED_PASSWORD in your untracked .env and NODE_ENV=development/test. PostgreSQL/Redis publish only on loopback. Compose
no longer auto-runs SQL from docker-entrypoint-initdb.d; migrations always run
through the checked runner. Existing volumes are preserved.

Optional container services: run migrations first, then
`docker compose -f infra/docker-compose.yml --profile services up -d --build`.
Container build/runtime has not been verified in this restricted session.

Create a dedicated test DB once (this creates data; it does not delete/reset):

```sh
docker compose -f infra/docker-compose.yml exec postgres createdb -U tipkhun tipkhun_test
pnpm build
pnpm test:integration
```

Set TEST_DATABASE_URL in .env to that DB. Runner refuses names not ending `_test`,
applies migrations, starts a test Risk Service on :13001, and executes the DB
suite. Tests use randomized users, preserve test history and perform no DROP,
TRUNCATE or destructive reset. A repeated createdb error only means the database
already exists; do not reset it. Unit tests run with `pnpm test`; DB tests are
explicitly skipped there and require the separate integration command.

Current environment: Docker daemon unreachable; launching Docker fails, and
standalone PostgreSQL initialization is denied shared-memory creation. Therefore
integration validation is BLOCKED, not passed. A reachable dedicated PostgreSQL
instance is required to finish Phase 2 acceptance.

Phase 2 acceptance is now complete. `pnpm test` includes build, unit and DB suites;
`pnpm test:unit` is DB-independent. `pnpm test:browser` starts isolated Auth/Risk/
Gateway on 14002/14001/14000 and Vite 15173 against TEST_DATABASE_URL, then runs
Chromium in the official Playwright v1.55.0-noble container. Docker accesses Vite
via the specifically allowlisted host.docker.internal hostname. No HTTP mocking.
`node tool/phase2-api.mjs` exercises the development API on port 3000.

## Phase 5

`pnpm db:migrate` applies 007–010 to the configured development DB. `pnpm dev` now also starts Portfolio Service at http://localhost:3006. Gateway /api/v1/portfolio routes to it. Docker's optional `services` profile includes portfolio-service and readiness checks. The normal provider uses fixture prices; no keys or external services are required.

`pnpm test:integration` runs Phase 2, Paper/ledger/allocation and Portfolio suites on a dedicated `_test` database. `pnpm test:browser` runs three browser flows plus the real Flutter remote repository acceptance against ports 14000–14006 and Vite 15173. Docker/Playwright and Flutter are required. It fails if any flow fails; there is no skipped-acceptance fallback. Flutter acceptance uses `--dart-define=PLATFORM_REPOSITORY=remote`; the ordinary Flutter UI remains local by default.

Migration 010 seals portfolio ledger entry sets after commit using the creating PostgreSQL transaction ID. Corrections must use a new header; even balanced entries cannot be appended to an old portfolio ledger transaction.
