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
