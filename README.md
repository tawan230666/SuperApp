# Tipkhun Capital · Beta

Flutter app for risk planning, a trade journal, and profit allocation. Continues the existing `superapp` project and package identifiers. Uses the original Tipkhun artwork, a rebuilt task-first workspace with charcoal navigation, a live risk gauge, restrained sage accents, and responsive page layouts, and bundled Noto Sans Thai typography.

## Run

```sh
flutter pub get
flutter run -d chrome
# Or select a connected Android/iOS device:
flutter devices
flutter run
```

## Implemented

- Five connected pages: overview, trade journal, profit router, long term, assistant.
- Daily dashboard: capital, net P/L after fees, remaining risk, trade count, daily loss limit, target, risk level and three progress bars.
- Low / Medium / High presets and Custom plan; money/percentage validation; Daily / Weekly / Monthly allocation preference.
- Trade asset, gross P/L, fees, local date/time, note and optional strategy. Today / 7 Days / 30 Days / All filters.
- Deterministic risk calculations in integer satang. Real trades can still be recorded after STOP, with a discipline violation. Backdated records are replayed chronologically.
- Editable allocation ratios totaling 100%, confirmation preview, rounding-safe allocation history and duplicate-profit prevention.
- Thirty-day risk history, total risk used, maximum daily cumulative loss and discipline score.
- Provider-independent assistant service with local rule-based answers from plan data; chat loading and error states.
- Persistent local data, loading/error/disabled states, responsive navigation, Beta/About and Settings > Legal & Risk Disclosure.

## Architecture

- `lib/main.dart`: responsive shell, navigation and journal/allocation/assistant flows.
- `lib/ui/dashboard.dart`: risk-first overview, quick actions, next steps, recent activity and discipline history.
- `lib/ui/workspace_widgets.dart`: shared visual system and accessible data-driven risk gauge.
- `lib/ui/plan_forms.dart`: validated input dialogs.
- `lib/state/plan_store.dart`: load/save state, publishes mutations only after successful persistence.
- `lib/domain/investment_plan.dart`: risk engine, journal, allocations, serialization and history.
- `lib/data/plan_repository.dart`: repository interface and shared-preferences storage.
- `lib/services/assistant_service.dart`: replaceable assistant interface and deterministic local implementation.
- `lib/ui/brand_mark.dart`: framing for the original supplied artwork; native/web icons use the same mark.
- `assets/fonts/`: bundled Noto Sans Thai and OFL license for offline typography.
- `tool/render_brand_test.dart`: regenerate platform icons and mobile/desktop previews for all five pages with `flutter test tool/render_brand_test.dart`.
- `docs/previews/`: rendered previews at 320px, 390px and 1440px.

## Calculation policy

Money is stored in satang and daily risk percentage in basis points. Daily risk used is the sum of negative net trade outcomes; winning trades never refill that budget. Risk and loss-limit consumption are separate displays. Loss-limit or risk-budget exhaustion takes precedence over a profit target. Reaching a target latches the stop for that local day, even if a later trade loses. Maximum trades and insufficient remaining risk also stop the plan.

The daily view resets at local midnight; records and allocations persist. Profit available for allocation is lifetime net P/L minus previously allocated profit, floored at zero. This preserves the original protection against allocating the same profit twice or ignoring later losses. The chosen allocation cycle is a planning preference; allocations require manual confirmation and are not automatic transfers or scheduled jobs.

Discipline score = trades without a violation / all trades that day × 100 (rounded). A violation is a trade after a stop condition or a net loss exceeding the per-trade risk allowance. Days without trades have no score. It measures compliance with this recorded plan, not investment skill. Risk History shows maximum cumulative loss per day, not intraday equity drawdown.

## Placeholders and limitations

- AI Long-Term Analysis is COMING SOON. No fabricated market quotes, asset scores or portfolio recommendations.
- Assistant uses local rules, not a connected AI API. Chat messages last for the current app session.
- No real-money transfers, broker connection, cloud sync or backup. Clearing app/browser data or uninstalling removes local records. Shared preferences is suitable for this beta journal, not a financial ledger or encrypted vault.
- The original plan lock after the first trade is retained to keep historical risk criteria stable. Plan versioning/editing after trading is a future extension. Allocation percentages remain editable.
- Initial ฿350 plan is editable before the first trade and contains no fabricated trade history.
- Reload tests use the repository with mocked platform preferences. Device restart and native iOS/macOS/Windows builds still need device-specific validation.

## Checks

```sh
dart format lib test
flutter analyze
flutter test
flutter build web
```

Tests cover existing risk rules, daily rollover, fees, backdating, discipline, rounding, persistence/reload, corrupt data, failed saves, and all five pages at 320px, 390px and desktop navigation.
