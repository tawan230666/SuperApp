import 'package:flutter/foundation.dart';
import '../data/plan_repository.dart';
import '../domain/investment_plan.dart';

class PlanStore extends ChangeNotifier {
  PlanStore(this.repository);
  final PlanRepository repository;
  InvestmentPlan plan = InvestmentPlan();
  bool loading = true, saving = false;
  String? error;
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      plan = await repository.load() ?? InvestmentPlan();
    } catch (_) {
      error = 'อ่านข้อมูลไม่ได้ กรุณาลองใหม่ ข้อมูลเดิมยังไม่ถูกเขียนทับ';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> commit(void Function(InvestmentPlan) change) async {
    if (saving || loading) return false;
    saving = true;
    notifyListeners();
    try {
      final next = InvestmentPlan.fromJson(plan.toJson());
      change(next);
      await repository.save(next);
      plan = next;
      error = null;
      return true;
    } catch (_) {
      error = 'บันทึกไม่สำเร็จ กรุณาลองใหม่';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> replace(InvestmentPlan next) async {
    if (saving) return false;
    saving = true;
    notifyListeners();
    try {
      await repository.save(next);
      plan = next;
      error = null;
      return true;
    } catch (_) {
      error = 'บันทึกแผนไม่สำเร็จ';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
