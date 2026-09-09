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
  bool loading = false;
  int _pending = 0;
  bool _disposed = false;
  bool get busy => _pending > 0;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  DateTime? observedAt;
  Future<void> load(InvestmentPlan plan) async {
    if (_disposed || loading || engine != null) return;
    loading = true;
    _publish();
    try {
      final raw = await repository.load();
      if (_disposed) return;
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
      _publish();
    }
  }

  Future<void> run(
    Future<void> Function() action, {
    bool emergency = false,
  }) async {
    if (_disposed || busy && !emergency) return;
    _pending++;
    error = null;
    _publish();
    try {
      await action();
      observedAt = DateTime.now().toUtc();
    } catch (e) {
      error = e.toString();
    } finally {
      _pending--;
      _publish();
    }
  }
}
