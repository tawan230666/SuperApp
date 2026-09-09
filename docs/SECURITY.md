# Security baseline

- `.env`, signing keys, local properties, build output and IDE caches are ignored. `.env.example` contains placeholders only.
- API gateway adds Helmet, CORS allowlist and a request ID. Services limit JSON body size and expose health endpoints.
- Browser TypeScript types are not trusted: shared Zod schemas parse runtime input. The risk service is deterministic and has no AI override.
- Passwords, tokens, broker keys and AI keys have no implementation or persistence path in the React/Flutter clients. Auth currently returns not-enabled rather than storing plain text.
- Database IDs are UUIDs; tenant and RBAC middleware are required before any non-local endpoint. SQL migrations use constraints and idempotency uniqueness.
- Audit table design records user, action, entity, request ID, state transition, source and UTC time. Service event names are shared for later queue use.
- Redis is cache/short-lived coordination only; financial truth belongs in PostgreSQL/ledger.

Before production: add dependency scanning, secret scanning, signed CI artifacts, TLS, secure cookies/CSRF strategy for auth, rate limits backed by Redis, structured redacted logs, tenant isolation tests, backups/restore drills and penetration testing. Live trading remains locked.
