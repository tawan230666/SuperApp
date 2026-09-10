# Market data foundation — fixture prices only

`MarketDataProvider` defines `getQuote`, `getQuotes`, `getHistoricalBars`, `searchAssets`, and `getAssetProfile`. `RealMarketDataProvider` is an interface for future work; there is no external provider connection or API key.

The curated asset identities are PTT (Stock) and TDEX (ETF), verified against the [SET PTT profile](https://www.set.or.th/en/market/product/stock/quote/ptt/company-profile/information) and [SET TDEX factsheet](https://www.set.or.th/en/market/product/etf/quote/tdex/factsheet). This is static identity metadata, not licensed price ingestion. Before connecting any external provider, review terms/rate limits and obtain the user's authorization. There is no endpoint for AI or clients to create asset identities. Migration 009 deactivates initial synthetic test symbols while preserving their historical foreign keys.

`FixtureMarketDataProvider` is the local default, with deliberately artificial prices: Stock 10 minor and ETF 20 minor. These are **not current, historical, recommended or executable exchange prices**. Asset identity, currency and type come from the curated DB catalog; these fixture prices do not imply real market valuation. The UI labels SIMULATION/PAPER and synthetic pricing prominently.

A quote contains symbol, integer `priceMinor`, THB currency, `timestamp`, `asOf`, `source`, `isDelayed`, `isStale`, and `marketStatus`. Sources are `fixture-paper` or `deterministic-paper`. OPEN means the fixture simulator accepts execution, not that SET is open. Default fixtures are generated as of request time. No fabricated historical bars: history exposes only the authenticated user's persisted execution quotes.

An order requires a quote no older than 60 seconds and no more than 5 seconds in the future, with OPEN status. Stale data yields `409 MARKET_DATA_STALE`; unavailable provider yields `503 MARKET_DATA_UNAVAILABLE`. Fresh delayed data can be used and remains labeled delayed. Valuation fails explicitly if an owned asset cannot be quoted; it does not replace missing prices with zero.

## Deterministic acceptance controls

`DeterministicMarketDataProvider` supports unchanged, up (+20%), down (−20%), stale (120 seconds), delayed (30 seconds), and unavailable. No randomness. Controls persist per authenticated user and asset, so test identities cannot change each other's prices.

`PUT /api/v1/market/test-scenario` exists **only if all** conditions hold:

- NODE_ENV is test or development;
- TEST_MODE=1;
- PAPER_MARKET_PROVIDER=deterministic;
- DATABASE_URL database name ends in `_test`.

Body: `{"symbol":"PTT","scenario":"up"}`. No arbitrary price field is accepted. Production/default service has no route for this control, even if test flags are accidentally set. Integration starts a production-configured local test process and verifies 404. Controls are absent from React UI/production bundle. Existing profitable Trading scenarios are also restricted to explicit test configuration and a dedicated test database.

Providers are replaceable through the interface without changing holdings/ledger accounting. Multi-currency FX, real-time subscriptions, exchange sessions/calendars, dividends/splits, ETF look-through and paid/public market ingestion remain out of scope.
