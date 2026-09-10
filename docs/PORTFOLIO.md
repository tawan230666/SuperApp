# Paper long-term portfolio

Phase 5 extends the existing PostgreSQL ledger and authenticated Gateway. No live execution, deposits, withdrawals, external market feed or AI is enabled.

## Ownership and funding

One THB Paper portfolio per authenticated user. `/portfolio/cash` returns both `cashMinor` and `longTermReservedCashMinor`; the latter remains compatible with Phase 4 clients. Funding consumes the available `LONG_TERM_RESERVE` ledger balance, never initial trading capital or a client-supplied balance.

Funding, orders and allocation serialize on the same PostgreSQL `users` row. Each funding/order request requires an 8–128 character `Idempotency-Key`. `(user_id,idempotency_key)` is unique, including across funding/orders. Identical canonical parsed JSON returns the original transaction; different content with the same key returns `409 IDEMPOTENCY_CONFLICT`. Decimal spellings are part of the request: retry the exact original payload. Keep the key when retrying network failures.

Portfolio transfers do not alter the historical Paper Broker custody balance. Trading's spendable-cash risk check subtracts long-term/withdrawal reserves **and cumulative portfolio funding**, preventing reuse by Trading. Do not sum custody cash and portfolio buckets as independent wealth. Portfolio gains remain in the portfolio; they are not automatically routed through the trading Profit Router.

## Quantities, fees and average cost

Money is integer THB minor units represented as JSON strings. Quantities are positive decimal strings with at most six fractional places, stored in PostgreSQL NUMERIC and operated on with BigInt at scale 1,000,000. No JavaScript floating-point money arithmetic.

- Notional = floor(quantity_scaled × quote_price_minor / 1,000,000). Below one minor unit is rejected.
- Paper fee = ceil(notional × 10 / 10,000), for each BUY and SELL.
- BUY: cash decreases by notional + fee; total holding cost increases by that same amount. Entry fees are capitalized, not separately expensed again.
- SELL: disposed cost = floor(old total cost × sold quantity / old quantity). Full liquidation consumes all remaining cost, including rounding remainder.
- Net realized P&L = sale notional − sale fee − disposed cost.
- Unrealized P&L = current market value − remaining total cost. This includes capitalized entry fees and excludes hypothetical future exit fees.
- Average cost shown in whole minor units is floor(total cost × scale / quantity); the exact total cost remains authoritative.

Weighted average cost is selected for a small deterministic simulator with fractional holdings; tax-lot/FIFO accounting is not implemented. All fees are stored once per immutable portfolio transaction. `PORTFOLIO_FEES` is reserved for a future alternative expense presentation and receives no duplicate fee posting under the current capitalized-cost policy.

Example: fund 300 minor; BUY 10 at 10 costs 100 + 1 fee = 101. Cash is 199. Mark at 12 gives market value 120 and unrealized P&L 19. SELL all at 12 receives 120 − 1; net realized P&L is 18 and cash is 318. Splitting the SELL into two executions incurs two separately rounded exit fees; the browser/Flutter acceptance therefore realizes 17.

## Ledger conventions

The existing reserve ledger uses credit-positive bucket balances. New portfolio funding/cost buckets follow that convention:

| Action | Debit | Credit |
| --- | --- | --- |
| Funding | LONG_TERM_RESERVE | PORTFOLIO_CASH |
| BUY | PORTFOLIO_CASH (notional + fee) | PORTFOLIO_COST (notional + fee) |
| Profitable SELL | PORTFOLIO_COST (disposed basis), PORTFOLIO_PNL (net gain) | PORTFOLIO_CASH (net proceeds) |
| Loss-making SELL | PORTFOLIO_COST (disposed basis) | PORTFOLIO_CASH (net proceeds), PORTFOLIO_PNL (net loss) |

The SELL cash leg posts gross proceeds as a credit and the exit fee as a separate debit to PORTFOLIO_CASH (the table shows their net). This also represents tiny fractional sales whose proceeds equal the fee without inventing profit or rejecting a balanced zero-net movement. Every transaction balances. Reported realized portfolio P&L is the **negative** credit-net balance of PORTFOLIO_PNL. Never reinterpret every bucket as a conventional debit-normal bank account.

Ledger entries, portfolio ledger headers, portfolio transactions and snapshots reject UPDATE/DELETE. A correction requires a new balanced reversal/compensating transaction referencing the original plus matching owned projection adjustments in one reviewed database transaction. Historical trades/entries must remain intact. No public correction/reversal endpoint or automatic balance repair is provided in Phase 5; a reconciliation latch requires reviewed operator remediation before release. Do not use reverse-market orders as an accounting reversal: those are new fee-bearing executions at a new price.

## Reconciliation and performance

Before mutations, compare portfolio cash with ledger cash and immutable transaction cash flow, holding total cost with ledger cost, per-asset quantity/cost with BUY minus SELL history, and transaction realized P&L with the PNL ledger. A mismatch commits `RECONCILIATION_REQUIRED`, emits one notification on first latch, and blocks funding/orders without silently changing amounts.

GET portfolio/holdings/targets/performance performs current server valuation. Successful valuation records an immutable snapshot of that actual observation; cash-only/empty portfolios may have legitimate zero snapshots. Historical chart points are never fabricated or backfilled. Provider failure/stale prices return an explicit error rather than a misleading valuation.

Total value = cash + market value. Return bps = (total value − cumulative funding) / cumulative funding × 10,000, truncated to integer bps; zero without funding. This is a simple funding-normalized return, **not** annualized, TWR or IRR. Drawdown uses peak observed (total value − cumulative funding) and the current funding plus positive peak as denominator; it is a basic cash-flow-adjusted indicator, not tick-level drawdown. Chart values include funding flows. Sector exposure treats an ETF as Diversified; no constituent look-through is claimed.

Targets are asset-level plus CASH; unique targets must sum to 10,000 bps. Concentration warnings use a configurable 1–10,000 bps threshold (default 6,000). No auto-sell or automatic rebalance.

## Clients

React `/long-term` uses only Gateway APIs, with funding and order preview/confirm, holdings, actual snapshot chart, allocations, sectors and watchlist. Preview does not place orders or post ledger entries. Confirm revalidates available cash/holdings and a fresh server quote; actual price can change after preview and the UI explains this.

Flutter exposes `PortfolioRepository`, `RemotePortfolioRepository`, `MarketDataRepository`, and `RemoteMarketDataRepository`. `portfolioRepositoryForMode` / `marketDataRepositoryForMode` select them when `PLATFORM_REPOSITORY=remote`; local returns null to preserve the existing local implementation. Inject one shared `RemoteHttpTransport`. No replacement Flutter portfolio UI is claimed. Existing local UI remains the default.

`pnpm test:browser` drives React BUY, runs `tool/portfolio_remote_acceptance_test.dart` with the remote flag against the same credentials/DB, then verifies the Flutter SELL and watchlist in React. Only the secure-storage platform channel is substituted with an ephemeral token store in this runner; HTTP, auth, refresh, portfolio and PostgreSQL are real.
