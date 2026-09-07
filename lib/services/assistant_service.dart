import '../domain/investment_plan.dart';

abstract interface class AssistantService {
  Future<String> reply(String question, InvestmentPlan snapshot);
}

class LocalAssistantService implements AssistantService {
  @override
  Future<String> reply(String question, InvestmentPlan snapshot) async {
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
