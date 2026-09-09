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
