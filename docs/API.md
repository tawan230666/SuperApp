# API contract (v1 foundation)

The gateway listens on `http://localhost:3000` and exposes a versioned REST surface. All request bodies are untrusted and must be parsed at the service boundary with Zod. Responses never contain secrets.

| Method | Route | Status in this milestone |
| --- | --- | --- |
| GET | `/health`, `/ready` | implemented on gateway and services |
| GET | `/api/v1` | lists capabilities and states Live as `LOCKED` |
| POST | `/api/v1/risk/check` | proxy to deterministic risk service |
| `/api/v1/auth`, `/users`, `/trades`, `/bot`, `/portfolio`, `/allocations`, `/ai` | reserved | individual service scaffold returns explicit not-enabled response |

Risk check uses minor units rather than floating point:

```json
{"capitalMinor":35000,"riskUsedMinor":0,"riskReservedMinor":0,"dailyLossLimitMinor":1750,"riskPerTradeMinor":500,"tradeCount":0,"maxTrades":3,"proposedRiskMinor":500,"emergencyStop":false,"marketDataAgeSeconds":1,"brokerConnected":true}
```

`RiskDecision` returns `approved`, `reason`, non-negative `riskRemainingMinor`, `tradesRemaining`, and `status`. It cannot be overridden by AI or a client supplied role. Add authentication, tenant scope and audit middleware before exposing this beyond local development.

## Phase 2 API (implementation; PostgreSQL integration not yet verified)

Gateway `http://localhost:3000`; auth `:3002`; risk `:3001`. JSON only.
Remote money fields are **decimal strings**, for example `"35000"`, not floats.

| Method | Gateway path | Behavior |
| --- | --- | --- |
| POST | /api/v1/auth/register | `{email,password}`; 201 only after committed user/account/audit |
| POST | /api/v1/auth/login | Access + refresh session; invalid credentials 401 |
| POST | /api/v1/auth/refresh | Rotate refresh; old token replay revokes session |
| POST | /api/v1/auth/logout | Bearer required; revoke session, return 204 |
| GET | /api/v1/auth/me, /api/v1/me | Authenticated identity, no hash |
| GET/PUT | /api/v1/risk/profile | Owned profile; GET null if absent |
| POST | /api/v1/plans | Create first plan; conflict 409 if present |
| GET/PUT | /api/v1/plans/current | GET null if absent; PUT creates next immutable version |
| GET | /api/v1/risk/status | Owned plan/account snapshot; 404 no plan, 409 incomplete profile |
| POST | /api/v1/risk/check | Only `{proposedRiskMinor:"100"}` accepted |

Auth service exposes equivalent `/v1/auth/*` routes. Risk service exposes
`POST /v1/risk/check`, requires the bearer token, and loads its own authoritative
DB context. Unknown client risk/identity fields are rejected. No order is placed;
response includes `mode: simulation` and `executionAuthorized: false`.

Profile: `{riskTolerance:500,dailyLossLimit:"1750",riskPerTrade:"500",
maxTrades:3,maxPositions:2,maxDrawdown:1000}`. Tolerance/drawdown use basis points.
Plan: `{capitalMinor:"35000",dailyLossLimitMinor:"1750",
riskPerTradeMinor:"500",maxTrades:3}`. Effective time is set on the server.
Plan limits are the authority for daily/per-trade budgets; profile amounts are
planning preferences, while maxPositions/maxDrawdown add server constraints.

Snapshot derives daily realized loss consumption from owned trades since UTC
midnight, reserved risk from non-terminal owned orders, and realized drawdown
from the owned trade ledger. Wins do not refill daily loss consumption. The
remote trading/order ingestion API is not implemented; this is a planning check,
not an execution reservation or authorization. Existing Flutter paper execution
remains local and is not reflected in this DB.

Browser sends `X-Auth-Client: web`, uses HttpOnly refresh cookie and in-memory
access token. Refresh requires an allowed Origin; mobile sends refreshToken in
JSON and must implement OS secure storage. Mobile refresh tokens must never be
stored by the skeleton transport in ordinary preferences.

## Phase 3 Paper Trading

Authenticated Gateway routes proxy to Trading Service (`TRADING_SERVICE_URL`,
default `http://localhost:3003`). All responses are Simulation/Paper; live
trading remains `LOCKED`.

`POST /api/v1/bot/start|pause|resume|stop|emergency-stop` validates bot state;
start creates a paper account from the current plan. Emergency stop atomically
latches the account and cancels pending orders while leaving positions open.
`GET /api/v1/bot/status` returns paper cash/equity/realized and unrealized P&L,
fees, open/pending counts, heartbeat and reconciliation state.

`POST /api/v1/orders` accepts only deterministic `SYNTHETIC-THB` MARKET paper
orders and requires `Idempotency-Key`. It creates a CREATED order, calls the
authoritative Risk Service reservation endpoint, then submits PaperBrokerAdapter.
GET order/list, cancel, partial-fill continuation, positions, explicit position
close, trades and reconcile endpoints are owned by authenticated user. Unknown
broker outcomes keep risk reserved and mark reconciliation required; reconcile
only repairs state when matching broker evidence exists. PostgreSQL enforces the
state graph and idempotency uniqueness. Scenarios `fill`, `partial`, `reject`,
`error`, `unknown`, and `slippage` are deterministic test controls, never market
randomness. Synthetic price, 10 bps fee and all money are integer minor units.
No broker or real-money execution path exists.

Health: `/health` liveness; `/ready` checks DB and required auth/risk schema on
Gateway/Auth/Risk, responds 503 on dependency failure. Validation 400, auth 401,
role denial 403, conflict 409; unexpected errors sanitized to 503.
## Phase 4 Paper operations and ledger

Authenticated Gateway routes proxy order/position/trade detail, reconciliation,
ledger summary/transactions, notifications, allocation settings/available/
preview/confirm/history, long-term cash and withdrawal reserve. Allocation
confirm requires `Idempotency-Key` and derives realized profit from PostgreSQL.
All values are Paper minor units; live execution remains LOCKED.

## Phase 5 — Paper Portfolio and fixture market data

All routes below require Bearer authentication and derive owner from that session. Money and quantity are strings; request bodies are strict and reject financial overrides. Portfolio Service runs on 3006 behind the existing Gateway.

| Method | Gateway path | Input / behavior |
| --- | --- | --- |
| GET | /api/v1/portfolio/cash | cashMinor, longTermReservedCashMinor, portfolioId, PAPER/THB |
| POST | /api/v1/portfolio/fund | {amountMinor:"300"}; Idempotency-Key required |
| GET | /api/v1/portfolio/funding-history | Owned immutable funding transactions |
| POST | /api/v1/portfolio/orders/preview | {side:"BUY",symbol:"PTT",quantity:"10"}; no execution/ledger mutation |
| POST | /api/v1/portfolio/orders | Same body, BUY or SELL; Idempotency-Key required |
| GET | /api/v1/portfolio/orders | Owned filled Paper executions, quote/ledger references |
| GET | /api/v1/portfolio | Server valuation, P&L, holdings, targets/deviations and risk |
| GET | /api/v1/portfolio/holdings | Owned current holdings with quote metadata |
| GET | /api/v1/portfolio/performance | Up to 200 real observed snapshots, chronological |
| GET/PUT | /api/v1/portfolio/targets | PUT {targets:[{target:"PTT",weightBps:6000},{target:"TDEX",weightBps:3000},{target:"CASH",weightBps:1000}],concentrationLimitBps:6000}; limit optional |
| GET | /api/v1/market/assets?q= | Curated active assets (up to 50) |
| GET | /api/v1/market/quotes/:symbol | Server fixture quote with freshness/source metadata |
| GET | /api/v1/market/history/:symbol | Owned observed execution quotes only |
| GET/POST | /api/v1/watchlist | POST {symbol:"PTT"} |
| DELETE | /api/v1/watchlist/:symbol | Remove own watchlist item |

Errors include 400 invalid input, 401 auth, 404 unknown asset, 409 INSUFFICIENT_RESERVE / INSUFFICIENT_CASH / INSUFFICIENT_HOLDINGS / IDEMPOTENCY_CONFLICT / MARKET_DATA_STALE / RECONCILIATION_REQUIRED, and 503 MARKET_DATA_UNAVAILABLE. Execution confirm revalidates a fresh price and balances; previews are estimates, not reserved quotes. GET valuation/performance creates an actual snapshot; order preview never posts ledger entries. Test-only market control and production guards are documented in MARKET_DATA.md. Live trading remains LOCKED.
