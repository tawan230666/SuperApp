# Tipkhun Capital — Emerald Capital

รีดีไซน์จากโปรเจกต์ Flutter เดิม ไม่เปลี่ยน package identifier, storage key, schema หรือสูตรคำนวณ

## ทิศทางภาพลักษณ์

ใช้มรกตเข้ม #073C31 สำหรับแบรนด์และการ์ดยอดสำคัญ เขียว #087F63 สำหรับการกระทำหลัก พื้นขาวและเทา #F3F6F5 และมิ้นต์ #93E7C6 สำหรับข้อมูลบนพื้นเข้ม สีทองใช้กับส่วนเงินสำหรับถอน สีแดงสงวนให้ผลขาดทุนและข้อผิดพลาด

ใช้ Noto Sans Thai ที่บันเดิลในแอป ตัวเลขเป็น tabular figures พร้อมย่อขนาดตามพื้นที่โดยไม่ตัดจำนวนเงิน ระยะหลัก 4 / 8 / 16 / 24 / 32 และมุมการ์ด 20 พิกเซล ปุ่มและช่องกรอกใช้มุม 12 พิกเซล

โลโก้เป็น C แบบเปิดล้อมเสาทุนสามแท่งไล่ระดับ สื่อถึง capital การเติบโต และฐานที่มั่นคง ไม่มีใบไม้หรือองค์ประกอบการ์ตูน วาดด้วย Flutter CustomPainter จึงคมชัดทุกขนาด มี SVG สำหรับส่งต่อและ PNG สำหรับใช้งานทั่วไป

## หน้าจอและ flow

- Overview: งบความเสี่ยงและสถานะเป็นข้อมูลหลัก ตามด้วยปุ่มบันทึกเทรด การ์ดเงินตั้งต้น กำไรสุทธิ เป้าหมาย และจำนวนเทรดจริง รวมกิจกรรมล่าสุด วินัย และจุดดำเนินการถัดไป
- บันทึกเทรด: แยกยอดสุทธิ จำนวนรายการ และค่าธรรมเนียม พร้อมช่วงเวลา รายละเอียดรายการ และ empty state
- แบ่งกำไร: แถบสัดส่วนตรงกับเปอร์เซ็นต์จริง การ์ดสามปลายทาง และ dialog ตรวจยอดก่อนยืนยัน รักษาการป้องกันแบ่งซ้ำและเศษสตางค์
- ระยะยาว: ยอดสะสม ประวัติการจัดสรร และคำอธิบายแยกยอดกันเงินออกจากมูลค่าพอร์ตจริง
- ผู้ช่วย: คำถามเริ่มต้น การสนทนา ช่องถามตรึงด้านล่าง เลื่อนไปคำตอบใหม่ สถานะกำลังตอบ และปุ่มลองส่งใหม่เมื่อผิดพลาด ระบุชัดว่ายังใช้กฎภายใน ไม่ได้เชื่อมต่อ AI
- ตั้งค่าแผน: แบ่งเป็นรูปแบบแผน เงินทุน/ความเสี่ยง จุดหยุด และรอบจัดสรร พร้อมชื่อระดับและรอบภาษาไทย หลังเทรดแรกเปิดรายละเอียดแบบอ่านอย่างเดียว
- ฟอร์มเทรด: แยกผลเทรดจากรายละเอียดเพิ่มเติม คง validation และการบันทึกผลจริงหลัง STOP
- Settings: เข้าถึงแผน ข้อมูลการใช้งาน ความเสี่ยง และข้อจำกัดการเก็บข้อมูลบนเครื่อง
- Loading/error: การ์ดสถานะพร้อมข้อความและปุ่มลองโหลดใหม่ การบันทึกยังแสดงความคืบหน้าและข้อผิดพลาดจาก store เดิม

## ไฟล์และคอมโพเนนต์

- `lib/ui/design_tokens.dart`: สี semantic และ CapitalSpace
- `lib/ui/app_theme.dart`: theme, typography, buttons, inputs, chips, navigation, dialogs, bottom sheets และ feedback
- `lib/ui/workspace_widgets.dart`: WorkspaceCard, SectionTitle, Amount, IconBadge, StatusPill, QuickAction, RiskGauge, EmptyJournal; เพิ่ม MetricGrid, MetricCard, AllocationBar, Notice, FormSection และ WorkspaceState
- `lib/ui/brand_mark.dart`: BrandMark และ CapitalMarkPainter
- `lib/ui/dashboard.dart`: responsive dashboard composition
- `lib/ui/plan_forms.dart`: ฟอร์มตั้งค่าแผน บันทึกผล และแก้สัดส่วน
- `lib/main.dart`: shell, หน้ารอง, composer, settings และ dialog ยืนยัน
- `assets/brand/tipkhun-mark.svg`, `tipkhun-mark.png`, `tipkhun-header.png`: ชุดแบรนด์พร้อมใช้
- ไอคอน Android, iOS, macOS, Windows และ Web สร้างจาก mark เดียวกัน
- `tool/render_brand_test.dart`: สร้างแบรนด์และภาพหน้าจอ 320 / 390 / 1440 พิกเซลใน `docs/previews/`
- `test/redesign_test.dart`: การตั้งค่าแผน การรักษาประวัติของแผนล็อก การโหลดใหม่ ช่องแชตเมื่อคีย์บอร์ดเปิด และฟอร์มจอแคบกับตัวอักษรขยาย

## การตรวจสอบ

ผลตรวจวันที่ 7 กันยายน 2026:

- `flutter analyze`: ไม่พบปัญหา
- `flutter test`: ผ่าน 22 รายการ
- `flutter test tool/render_brand_test.dart`: ผ่าน ส่งออกภาพหน้าจอและแบรนด์สำเร็จ
- `flutter build web`: สำเร็จที่ `build/web`
- ตรวจภาพหน้าจอ Overview, Allocation, Assistant และฟอร์มด้วยสายตา พร้อมทดสอบ layout ทุกหน้าและทุกฟอร์มที่ 320 / 390 / 1440 พิกเซล

ไฟล์ `investment_plan.dart`, `plan_store.dart`, `plan_repository.dart` และ `assistant_service.dart` ไม่เปลี่ยนจากรุ่นก่อนรีดีไซน์ ตรวจเทียบเนื้อหาไฟล์โดยตรงด้วย

## ขอบเขตที่ยังเหลือ

การเชื่อมต่อ AI จริง ข้อมูลตลาด การซื้อสินทรัพย์ Cloud sync/backup และการแก้แผนแบบมี version ยังเป็นงานต่อยอดเดิม ต้องทดสอบสัมผัสจริง คีย์บอร์ด และ screen reader บนอุปกรณ์ iOS/Android ก่อนเผยแพร่ native release การทดสอบ widget ไม่แทนการทดสอบอุปกรณ์จริง
