# Local infrastructure

`docker-compose.yml` starts PostgreSQL and Redis by default. API/risk containers are behind the `services` profile while the TypeScript workspace lockfile and image review mature.

```sh
docker compose -f infra/docker-compose.yml config
docker compose -f infra/docker-compose.yml up -d postgres redis
docker compose -f infra/docker-compose.yml --profile services up --build
```

PostgreSQL owns transactional records; Redis is cache/queue/short-lived coordination only. Local credentials in Compose are development fixtures, never production credentials.
