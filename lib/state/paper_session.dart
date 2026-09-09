import 'package:flutter/foundation.dart';
import '../data/paper_repository.dart';
import '../domain/investment_plan.dart';
import '../trading/paper_engine.dart';

/// One client-local synthetic session. Replace with an authenticated API client
/// before adding external execution; never ship broker or AI secrets to Flutter.
class PaperSession extends ChangeNotifier {
  PaperSession(this.repository);
  final PaperRepository repository;
  PaperEngine? engine;
  String? error;
  bool loading = false, busy = false;
  DateTime? observedAt;
  Future<void> load(InvestmentPlan plan) async {
    if (loading || engine != null) return;
    loading = true;
    notifyListeners();
    try {
      final raw = await repository.load();
      final broker = MockBrokerAdapter();
      engine = raw == null
          ? PaperEngine(plan: plan, broker: broker, save: repository.save)
          : PaperEngine.restore(raw, broker, repository.save);
      error = null;
      observedAt = DateTime.now().toUtc();
    } catch (_) {
      error = 'อ่านข้อมูล Paper ไม่ได้ ข้อมูลเดิมไม่ถูกเขียนทับ';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> run(
    Future<void> Function() action, {
    bool emergency = false,
  }) async {
    if (busy && !emergency) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      observedAt = DateTime.now().toUtc();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
