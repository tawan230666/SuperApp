import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/data/plan_repository.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/state/plan_store.dart';

class FailingRepository implements PlanRepository {
  @override
  Future<InvestmentPlan?> load() async => null;
  @override
  Future<void> save(InvestmentPlan plan) async => throw StateError('disk full');
}

void main() {
  test(
    'reload preserves trades, fees, ratios and allocation without duplication',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalPlanRepository();
      final p = InvestmentPlan();
      p.record('TEST', 10001, fees: 1, note: 'note', strategy: 'strategy');
      p.setAllocation(40, 40, 20);
      p.allocate();
      await repository.save(p);
      final restored = (await LocalPlanRepository().load())!;
      expect(restored.totalPnl, 10000);
      expect(restored.trades.single.fees, 1);
      expect(restored.trades.single.note, 'note');
      expect(restored.longTerm, 4000);
      expect(restored.distributable, 0);
      expect(restored.shortPercent, 40);
    },
  );
  test('failed save does not publish unsaved trade', () async {
    final store = PlanStore(FailingRepository());
    await store.load();
    expect(await store.commit((p) => p.record('A', 100)), false);
    expect(store.plan.trades, isEmpty);
    expect(store.error, isNotNull);
    store.dispose();
  });
  test('corrupt storage is surfaced without overwriting', () async {
    SharedPreferences.setMockInitialValues({LocalPlanRepository.key: 'broken'});
    final store = PlanStore(LocalPlanRepository());
    await store.load();
    expect(store.error, isNotNull);
    expect(
      (await SharedPreferences.getInstance()).getString(
        LocalPlanRepository.key,
      ),
      'broken',
    );
    store.dispose();
  });
  test(
    'daily rollover resets budget but preserves unallocated lifetime profit',
    () {
      var now = DateTime(2026, 9, 7, 12);
      final p = InvestmentPlan(clock: () => now);
      p.record('A', 3000);
      expect(p.stopReason, isNotNull);
      now = DateTime(2026, 9, 8, 12);
      expect(p.pnl, 0);
      expect(p.remaining, 1750);
      expect(p.stopReason, isNull);
      expect(p.distributable, 3000);
    },
  );
  test('fees consume risk and backdated entries replay discipline', () {
    final now = DateTime(2026, 9, 7, 12);
    final p = InvestmentPlan(clock: () => now);
    p.record('later', 100, time: DateTime(2026, 9, 7, 11));
    p.record('earlier', -1800, fees: 100, time: DateTime(2026, 9, 7, 10));
    expect(p.losses, 1900);
    expect(p.trades.last.outsidePlan, true);
    expect(p.tradingStatus, 'STOP');
    expect(p.history.first.score, 0);
  });
  test('allocation validates total and preserves rounding', () {
    final p = InvestmentPlan();
    expect(() => p.setAllocation(50, 30, 30), throwsArgumentError);
    p.setAllocation(33, 33, 34);
    p.record('A', 101);
    p.allocate();
    expect(p.reinvestment + p.longTerm + p.withdrawal, 101);
  });
}
