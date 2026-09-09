# Tipkhun Capital

แอปวางแผนความเสี่ยง บันทึกเทรด จัดสรรกำไร และทดลอง Paper Trading จาก **Flutter codebase เดียวสำหรับ Android, iOS และ Web** ไม่มีเงินจริงหรือการรับประกันผลตอบแทน

## Run

```sh
flutter pub get
flutter devices
flutter run -d chrome       # Web
flutter run -d DEVICE_ID    # Android / iOS ที่ตั้งค่า toolchain แล้ว
```

## Verify and build

```sh
dart format .
flutter analyze
flutter test
flutter build web
# ภาพ review จาก Flutter renderer (ไม่ใช่ browser screenshot)
flutter test tool/render_web_test.dart
```

Release Web อยู่ที่ `build/web`. วิธี preview, hosting, Free Tier และ smoke checklist อยู่ใน [WEB_DEPLOYMENT.md](docs/WEB_DEPLOYMENT.md). ยังไม่ได้ deploy หรือเปิด billing

หาก environment จำกัด telemetry ใช้ prefix `FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true` กับคำสั่ง Flutter/Dart

## Web navigation and responsive design

Flutter Router API, default hash URLs สำหรับ refresh บน static hosting:

- `/#/dashboard` (หรือ `/`)
- `/#/trades`
- `/#/profit-router`
- `/#/long-term`
- `/#/assistant`
- `/#/bot`
- `/#/bot/strategies`
- `/#/bot/backtest`
- `/#/risk-analytics`
- `/#/settings`

Mobile <600px, Tablet 600–1023px, Desktop ≥1024px. Mobile/Tablet คง Bottom Navigation 5 เมนู; Desktop มี Sidebar, account/mode/connection status และ notification/profile information. เนื้อหามี max width และ grid ไม่ยืด card เต็มจอกว้าง 1920px

Desktop journal มีตารางแบบแบ่งหน้า, search, asset/strategy/date filters และ Export CSV ผ่าน preview/copy clipboard พร้อมป้องกันสูตร spreadsheet. Side/Entry/Exit ที่ไม่มีในโมเดลเดิมแสดง —. Mobile ใช้ cards จากข้อมูลเดียวกัน

กราฟ Recorded Equity, Daily P&L, Drawdown และ Allocation ใช้ข้อมูลบันทึกและสูตรเดียวกับ Mobile; ไม่มีข้อมูลจะแสดง Empty State. Recorded Equity ไม่ใช่ยอดโบรกเกอร์หรือมูลค่าตลาด

## Current features

- Daily Risk Engine ใช้ integer satang / basis points; ขาดทุนสะสมใช้ risk budget โดยกำไรไม่เติมกลับ
- Journal พร้อม fees, backdating, notes, strategy และ discipline replay
- Profit Router preview/confirmation, rounding และป้องกันจัดสรรกำไรซ้ำ
- 30-day risk history, discipline score, responsive charts
- Paper Bot: Start/Pause/Stop, confirmed Emergency Stop, risk reservation, idempotency, order status, reconciliation และ audit events
- Read-only Copilot: reuse AssistantService, local rule-based plan summary และ paper status; แจ้งว่าไม่มี Strategy/Backtest ที่ยังไม่เกิดขึ้น
- Long-term cash allocation/history; holdings, market value, research และ AI Analysis ยัง Coming Soon
- ใช้โลโก้ต้นฉบับ T ที่กู้จากประวัติ GitHub รวม platform icons

## Paper / AI status

Broker เป็น **local synthetic Mock** ของ SYNTHETIC-THB. Full notional risk, long-only, หนึ่ง open position, ไม่มี leverage. ราคาเปิด/ปิดเท่ากันในตัวจำลอง; fees/spread สมมติเป็น 0 และระบุชัด ไม่มีตลาดสดหรือกลยุทธ์อัตโนมัติ

PaperSession อยู่ระดับ workspace เพื่อไม่สร้าง engine ใหม่เมื่อสลับหน้า. Refresh โหลด snapshot แล้ว pause; reconcile ก่อนจัดการ position เดิม. Unknown outcome เก็บ reservation และไม่ส่งซ้ำ. Emergency Stop คง position ให้ตรวจ/ปิดเอง ไม่รับประกัน liquidation

AI Agent panel แสดง OFFLINE ตามจริง ไม่มี LLM API, research run, strategy promotion หรือ backtest. Chat ใช้กฎภายใน ไม่อ้าง confidence หรือราคาตลาด

## Architecture and structure

- `lib/navigation/app_router.dart`: URL parsing / navigation state
- `lib/ui/app_shell.dart`: shared shell, breakpoints, responsive page container
- `lib/ui/dashboard.dart`, `web_panels.dart`: dashboard, chart/grid, risk analytics, honest agent/research placeholders
- `lib/ui/trade_table.dart`: shared filters, paginated desktop journal, escaped CSV
- `lib/ui/bot_dashboard.dart`: responsive paper controls and confirmation
- `lib/main.dart`: shared application flows, plan/journal/allocation/chat
- `lib/domain/investment_plan.dart`: existing deterministic accounting and journal logic, unchanged in Web milestone
- `lib/trading/paper_engine.dart`: synthetic execution gateway, unchanged in Web milestone
- `lib/state/plan_store.dart`, `paper_session.dart`: state and persistence boundaries
- `lib/data/plan_repository.dart`, `paper_repository.dart`: replaceable storage interfaces and local adapters
- `lib/services/assistant_service.dart`: read-only rule-based provider
- `test/`: regression, domain, persistence, routing, CSV, responsive/widget tests
- `tool/render_web_test.dart`: reproducible visual review; output `docs/previews/web/`

Future shared architecture: Mobile/Web → authenticated API → server-side risk/orchestrator/AI/broker → durable DB/ledger/audit. Flutter is client only. Do not put broker credentials, AI keys or DB passwords in Flutter, assets, dart-define or SharedPreferences

## Data and limitations

Existing `tipkhun.plan.v1` and `tipkhun.paper.synthetic.v1` keys/schema remain unchanged. No reset or migration. Paper profits are not copied into manual allocations. Profit reserved for withdrawal is not withdrawn cash. Allocation ratios remain editable; plan locks after first manual trade pending Plan Versioning

SharedPreferences is local prototype storage, not a transactional ledger, encrypted vault, cross-device backup or multi-tab coordinator. Use one Paper tab. Clearing browser data/uninstalling loses local records; changing origin uses different storage. Journal days use device-local timezone; Paper accounting days use Bangkok/UTC storage

No production auth, payments, cloud sync, worker, official broker, market feed, live mode, double-entry ledger or strategy sandbox. No offline guarantee. Chat history is session-only

## Validation and Git

2026-09-09: baseline 33 tests passed; final responsive Web suite 45 tests passed; optional visual renderer test passed (1 test). See [PROGRESS](docs/PROGRESS.md) for final results. Native iOS build unavailable: incomplete Xcode and missing CocoaPods. Chrome launch failed in this managed environment, so browser refresh/back/forward and actual device E2E still require smoke testing before release

Source initially had no `.git`. Checkpoint `04cc5e3` was pushed to `feature/web-platform` without rewriting main. Managed workspace `.git` is read-only; commit/push uses a separate checkout. See [GIT_WORKFLOW](docs/GIT_WORKFLOW.md) for reconnecting source metadata safely

[Architecture](docs/ARCHITECTURE.md) · [Decisions](docs/DECISIONS.md) · [Next Steps](docs/NEXT_STEPS.md)

## Repository policy

`tawan230666/SuperApp` is the shared Tipkhun Capital Mobile + Web repository. Business logic, data models, risk, AI interfaces and branding stay shared. Future API/server code belongs in `backend/` when implemented. Web work stays on `feature/web-platform`; trading-bot, ai-agent and backend branches can be created when those tasks begin. Merge into main after validation.

A future corporate/marketing website may have its own repository; no separate Web App repository or GitHub Project is needed now. Domain examples are planning only, not purchased or deployed sites.
