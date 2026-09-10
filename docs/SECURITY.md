# Security — Phase 2 implementation / validation pending

The system remains Simulation/Paper only. Live trading, production deployment,
payments, withdrawals, broker credentials and paid AI are LOCKED.

## Credentials and sessions

Passwords use bcrypt cost 12, minimum 12 characters, maximum 72 UTF-8 bytes to
avoid bcrypt truncation. Shared Zod contracts reject client role assignment.
Registration commits user, simulation account and audit atomically. Database
errors cannot return success. Email is normalized and uniquely constrained.

Opaque cryptographically random 256-bit access and refresh tokens avoid JWT
key distribution. No JWT_SECRET is needed. DB stores SHA-256 digests only.
Access lifetime: 10 minutes. Refresh lifetime: 7 days, with a 30-day absolute
session cap. Rotation locks token/session rows. Reuse of a consumed refresh token
revokes the family. Logout revokes the session, immediately invalidating access
and refresh tokens. Every authenticated request consults session state in DB.

Web stores access token in memory and refresh token in HttpOnly, SameSite=Strict
cookie (Secure in production), never localStorage. Browser refresh requires a
custom header and allowlisted Origin; JSON/custom-header requests require CORS
preflight. Local Vite proxies `/api` to Gateway. Production HTTPS and same-site
routing remain deployment requirements, not a deployed configuration. Concurrent
refresh is deduplicated per tab; cross-tab coordination remains PARTIAL and may
cause safe session revocation on simultaneous rotation. Cookie path `/` allows
the auth service and Gateway route aliases; no Domain attribute is set.
Mobile receives refresh token in JSON; OS secure storage and transport are still
PARTIAL skeleton work, not wired into the existing local Flutter app.

## Authorization and risk

authenticate() sets server-owned identity and request context; authorize()
checks roles. Current routes use ownership regardless of admin role. Parameterized
queries scope profiles/plans/accounts/trades/orders/positions to identity.id.
There are no public read/write endpoints for other users' trades, accounts,
allocations or portfolios; those scaffold services remain nonfunctional.
PostgreSQL RLS is not implemented. Integration ownership tests are written but
not yet executed against PostgreSQL in this environment.

Remote risk accepts only proposedRiskMinor. Plan and usage are loaded from DB;
client/AI cannot replace capital, limits, usage, trades, stop flags or positions.
The old local pure risk engine remains for regression compatibility. The new
check is a planning decision and cannot authorize execution; an atomic order
reservation/settlement service is still required before remote paper trading.

## HTTP and auditing

Helmet, CORS allowlist, 32kb JSON limit, server-generated request IDs, no-store
responses, general 120/minute and auth 40/15-minute IP limits. Rate limits are
in-process per service (Redis-backed distribution remains PARTIAL). No proxy
trust is enabled by default. Unexpected errors return generic messages without
stack traces, tokens or SQL details. Password/token fields are never returned
in user payloads or written to audits/logs. Audit actions include registration,
login, logout, profile update, plan creation and plan version creation.

Local Compose credentials are development-only. `.env` and private keys remain
ignored. No production secret, AI key or broker credential is introduced.
Production readiness still requires distributed limiting, secret/dependency
scanning, TLS, backups/restore, session cleanup, email verification/recovery and
security review. No production-readiness claim is made.
