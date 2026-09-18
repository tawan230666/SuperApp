import '../domain/investment_plan.dart';
import 'dart:convert';

abstract interface class AssistantService {
  Future<String> reply(String question, InvestmentPlan snapshot);
}

class LocalAssistantService implements AssistantService {
  LocalAssistantService({this.readPaper});
  final String? Function()? readPaper;
  @override
  Future<String> reply(String question, InvestmentPlan snapshot) async {
    final q = question.toLowerCase();
    if (q.contains('backtest') ||
        q.contains('ย้อนหลัง') ||
        q.contains('strategy') ||
        q.contains('กลยุทธ์')) {
      return 'ยังไม่มี Strategy Registry หรือ BacktestRun ให้สรุป manual-synthetic-v1 เป็นคำสั่งทดลองด้วยตนเอง ไม่ใช่กลยุทธ์ที่ผ่านการประเมิน • แหล่งข้อมูล: ความสามารถของแอปรุ่นนี้';
    }
    if (q.contains('bot') || q.contains('บอท')) {
      final raw = readPaper?.call();
      if (raw == null) {
        return 'ยังอ่านสถานะ Paper session ไม่ได้ จึงไม่สามารถยืนยันสถานะบอทได้';
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final events = data['events'] as List;
      return 'Paper Bot: ${data['state']} • เหตุผล: ${data['reason'] ?? "ไม่มีเหตุหยุด"} • คำสั่งสะสม ${(data['orders'] as List).length} รายการ\nแหล่งข้อมูล: local Paper session • เหตุการณ์ล่าสุด (UTC): ${events.isEmpty ? "ยังไม่มี" : events.last['time']}\nMock Broker ไม่มีข้อมูลตลาดจริงหรือ worker เบื้องหลัง';
    }
    if (question.contains('หยุด')) {
      return snapshot.stopReason ??
          'ยังไม่ถึงเงื่อนไขหยุดของแผน เหลือ ${snapshot.tradesLeft} เทรด การมีงบเหลือไม่ได้หมายความว่าควรเข้าเทรด';
    }
    if (question.contains('แบ่ง')) {
      final a = snapshot.preview();
      return 'กำไรที่ยังแบ่งได้ ${money(a.amount)} • ระยะสั้น ${money(a.short)} • ระยะยาว ${money(a.long)} • ถอน ${money(a.withdraw)} เป็นการวางแผนเท่านั้น';
    }
    if (question.contains('เสี่ยง')) {
      return 'งบวันนี้ ${money(snapshot.budget)} ใช้ไป ${money(snapshot.losses)} เหลือ ${money(snapshot.remaining)} กำไรไม่เพิ่มงบเสี่ยงกลับ';
    }
    return 'ทุน ${money(snapshot.capital)} ผลสุทธิวันนี้ ${money(snapshot.pnl)} บันทึกวันนี้ ${snapshot.today.length} เทรด สถานะ ${snapshot.tradingStatus} ระยะยาวสะสม ${money(snapshot.longTerm)}\nผู้ช่วยรุ่นนี้สรุปจากข้อมูลแผนตามกฎ ยังไม่ได้เชื่อม AI API';
  }
}
