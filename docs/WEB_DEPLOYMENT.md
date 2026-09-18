# Tipkhun Capital Web deployment preparation

เอกสารวันที่ 9 กันยายน 2026 — ยังไม่ได้ deploy, ซื้อ domain หรือเปิด billing

## Build และ preview ในเครื่อง

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

เปิด `http://127.0.0.1:8765/#/dashboard` หรือ `/#/bot` ข้อมูลจะอยู่เฉพาะ origin/browser นี้ การเปลี่ยน hostname/port จะเห็น storage คนละชุด ไม่ใช่การลบข้อมูล

แอปใช้ Flutter Router API และ default hash URL เช่น `/#/trades`, `/#/bot/strategies`, `/#/bot/backtest` จึง refresh บน static hosting ได้โดยไม่ส่ง route fragment ให้ Server การเปลี่ยนเป็น URL ไม่มี # ต้องใช้ PathUrlStrategy และ SPA rewrite; รอบนี้ยังไม่เปลี่ยน [Flutter URL strategies](https://docs.flutter.dev/ui/navigation/url-strategies)

## เปรียบเทียบทางเลือก

ตรวจจากเอกสารผู้ให้บริการวันที่ 9 กันยายน 2026 ตัวเลขและเงื่อนไขอาจเปลี่ยน ต้องตรวจซ้ำก่อนเปิดบริการ

| Hosting | Free tier / เงื่อนไขที่เกี่ยวข้อง | วิธีเตรียม |
| --- | --- | --- |
| Firebase Hosting | Spark มีโควตา storage/transfer แบบไม่เสียเงิน การใช้เกินอาจทำให้ไซต์หยุดจนรอบใหม่ หากไม่อัปเกรด | มี `firebase.json` ใช้ `build/web` และ cache headers; ยังไม่เลือก project หรือเปิด billing |
| Cloudflare Pages | Free มี 500 builds/เดือน, 20,000 files และขนาดไฟล์สูงสุด 25 MiB | build ในเครื่องแล้ว Direct Upload; มี `_headers`, `_redirects` ใน `web/` |
| Vercel | Hobby จำกัด personal/non-commercial จึงไม่ควรถือว่าเหมาะกับการเปิดธุรกิจ Tipkhun Capital โดยอัตโนมัติ | static output ใช้ได้ แต่ต้องตรวจแผน/เงื่อนไขก่อน deployment |

แหล่งข้อมูล: [Firebase quotas](https://firebase.google.com/docs/hosting/usage-quotas-pricing), [Cloudflare limits](https://developers.cloudflare.com/pages/platform/limits/), [Vercel Hobby](https://vercel.com/docs/plans/hobby)

## ขั้นตอนหลังเจ้าของอนุมัติ deployment เท่านั้น

- Firebase: ติดตั้ง Firebase CLI, login, เลือกโครงการที่อนุมัติด้วย `firebase use --add`, ตรวจ Spark/billing, build แล้วใช้ `firebase deploy --only hosting`. คำสั่งนี้เผยแพร่เว็บไซต์จริง จึงยังไม่ได้รัน
- Cloudflare: สร้าง Pages Direct Upload project ที่อนุมัติ แล้วอัปโหลด **เนื้อหา** `build/web`; หรือใช้ Wrangler CLI `wrangler pages deploy build/web --project-name PROJECT_NAME` หลังตรวจบัญชีและสิทธิ์ [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)
- Vercel: ใช้ static artifact จาก `build/web` กับโครงการ/แผนที่เจ้าของอนุมัติ ไม่ผูก repository เข้ากับ auto production deployment ในรอบนี้
- Subdirectory hosting: build ด้วย `flutter build web --base-href /SUBPATH/` แล้วทดสอบ URL/hash/assets อีกครั้ง

## Release smoke checklist

1. ตรวจ 390/768/1024/1440/1920px และ text scaling 150%; sidebar/bottom navigation, scroll, table horizontal scroll, pagination, dialogs และ Empty State
2. เปิดทุก URL ตรง ๆ; refresh; กด browser Back/Forward; unknown URL ต้องแสดงไม่พบหน้า
3. บันทึก manual trade พร้อม fees แล้ว refresh: ยอดคงเดิม; allocation preview/confirm ไม่แบ่งซ้ำ
4. เปิด Paper, Start, ซื้อจำลอง, เปลี่ยนหน้าแล้วกลับ: session เดิม; refresh: PAUSED และ reservation คงอยู่; reconcile/close ได้
5. Emergency confirmation: ยกเลิกต้องไม่หยุด; ยืนยันต้องล็อกและบล็อก order ใหม่
6. CSV ส่งออกเฉพาะข้อมูลที่กรอง; formula-prefix ถูก escape; การคัดลอก clipboard ต้องใช้ secure context (HTTPS/localhost)
7. ดู DevTools Console/Network: ไม่มี uncaught errors, missing assets หรือ secrets ใน bundle; ตรวจ initial renderer/CanvasKit downloads ตามเครือข่าย deploy จริง
8. CSP ควรออกแบบหลังตรวจ renderer และ endpoint จริง ไม่ใส่นโยบายเดาที่ทำให้ Flutter โหลดไม่ได้

## ข้อจำกัดสำคัญ

Flutter Web เป็น client; local mock ไม่ใช่ระบบส่งคำสั่งจริงหรือ server-side enforcement. ห้ามเก็บ AI/Broker key ใน dart-define, JS, Flutter assets หรือ SharedPreferences. Auth/API, execution, broker secrets, immutable audit, AI worker และ risk enforcement ต้องอยู่ Backend ร่วมของ Mobile/Web ก่อนใช้งานจริง

ไม่มี multi-tab coordination: ใช้ Paper simulator เพียงแท็บเดียว ข้อมูล SharedPreferences ไม่ใช่ ledger หรือ backup. ไม่มี offline/service-worker guarantee, cloud sync หรือ production auth

ผลในสภาพแวดล้อมพัฒนา: Widget/Domain tests ผ่าน; release web build ผ่าน. Chrome launch ล้มเหลวทั้ง headless และ `flutter run -d chrome` (เครื่องมือลอง 3 ครั้ง) จึงต้องทำ browser smoke checklist บนเครื่องที่เปิด browser ได้ก่อนเผยแพร่
