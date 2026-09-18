import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/trading/paper_engine.dart';

class UncertainBroker extends MockBrokerAdapter {
  int calls = 0;
  @override
  Future<int> placeOrder(String id, int quantity, int limit) async {
    calls++;
    await super.placeOrder(id, quantity, limit);
    throw TimeoutException('accepted but response lost');
  }
}

class PartialBroker extends MockBrokerAdapter {
  @override
  Future<int> placeOrder(String id, int quantity, int limit) async => 1;
}

class SlowConnectBroker extends MockBrokerAdapter {
  final gate = Completer<void>();
  @override
  Future<void> connect() async {
    await gate.future;
    await super.connect();
  }
}

class LossBroker extends MockBrokerAdapter {
  @override
  Future<int> closePosition(String id) async => 0;
}

class StaleBroker extends MockBrokerAdapter {
  @override
  DateTime get marketTime => DateTime.utc(2000);
}

void main() {
  PaperEngine make({MockBrokerAdapter? broker, SavePaper? save}) => PaperEngine(
    plan: InvestmentPlan(),
    broker: broker ?? MockBrokerAdapter(),
    save: save ?? (_) async {},
  );
  test(
    'concurrent entries reserve once, duplicate retries do not submit',
    () async {
      final e = make();
      await e.start();
      final result = await Future.wait([
        e.submit('a', limit: 500),
        e.submit('b', limit: 500),
        e.submit('a', limit: 500),
      ]);
      expect(result.map((o) => o.state), [
        OrderState.filled,
        OrderState.rejected,
        OrderState.filled,
      ]);
      expect(e.reserved, 500);
      expect(e.remaining, 1250);
      await expectLater(e.submit('a', limit: 501), throwsArgumentError);
    },
  );
  test('unknown submission reconciles without retry and holds risk', () async {
    final broker = UncertainBroker();
    final e = make(broker: broker);
    await e.start();
    expect((await e.submit('a')).state, OrderState.unknown);
    await e.submit('a');
    expect(broker.calls, 1);
    expect(e.reserved, 100);
    await e.reconcile();
    expect(e.orders.single.state, OrderState.filled);
  });
  test('partial fill retains entire reservation', () async {
    final e = make(broker: PartialBroker());
    await e.start();
    expect(
      (await e.submit('a', quantity: 2)).state,
      OrderState.partiallyFilled,
    );
    expect(e.reserved, 200);
    await expectLater(e.close('a'), throwsStateError);
  });
  test('risk, stale data and disconnected broker reject', () async {
    final e = make();
    await e.start();
    expect((await e.submit('risk', limit: 501)).state, OrderState.rejected);
    await e.broker.disconnect();
    expect((await e.submit('offline')).reason, 'Broker disconnected');
    final stale = make(broker: StaleBroker());
    await stale.start();
    expect((await stale.submit('stale')).reason, 'Stale market data');
  });
  test('emergency prevents entries and allows explicit flat close', () async {
    final e = make();
    await e.start();
    await e.submit('a');
    await e.emergencyStop();
    expect((await e.submit('b')).state, OrderState.rejected);
    await e.close('a');
    expect(e.reserved, 0);
    expect(e.pnl, 0);
    await expectLater(e.start(), throwsStateError);
  });
  test('storage failure locks before broker execution', () async {
    var fail = false;
    final broker = UncertainBroker();
    final e = make(
      broker: broker,
      save: (_) async {
        if (fail) throw StateError('disk');
      },
    );
    await e.start();
    fail = true;
    await expectLater(e.submit('a'), throwsStateError);
    expect(broker.calls, 0);
    expect(e.state, BotState.locked);
  });
  test(
    'restore preserves plan snapshot, positions, audit and legacy JSON',
    () async {
      final legacy = InvestmentPlan()
        ..record('old', 101)
        ..allocate();
      final before = legacy.toJson();
      String? raw;
      final e = PaperEngine(
        plan: legacy,
        broker: MockBrokerAdapter(),
        save: (s) async {
          raw = s;
        },
      );
      await e.start();
      await e.submit('a');
      final restored = PaperEngine.restore(
        raw!,
        MockBrokerAdapter(),
        (_) async {},
      );
      expect(restored.state, BotState.paused);
      expect(restored.reserved, 100);
      await restored.reconcile();
      await restored.close('a');
      expect(restored.orders.single.state, OrderState.closed);
      expect(legacy.toJson(), before);
      expect(restored.plan.toJson(), before);
    },
  );
  test('exact daily loss stops new orders; integer accounting', () async {
    final e = PaperEngine(
      plan: InvestmentPlan(dailyLossLimit: 101, riskPerTrade: 101),
      broker: LossBroker(),
      save: (_) async {},
    );
    await e.start();
    await e.submit('loss', limit: 101);
    await e.close('loss');
    expect(e.pnl, -101);
    expect(e.losses, 101);
    expect(e.remaining, 0);
    expect(e.state, BotState.stopped);
    expect((await e.submit('blocked')).state, OrderState.rejected);
  });

  test('emergency during connect cannot reactivate bot', () async {
    final broker = SlowConnectBroker();
    final e = make(broker: broker);
    final starting = e.start();
    await Future<void>.delayed(Duration.zero);
    final stopping = e.emergencyStop();
    broker.gate.complete();
    await starting;
    await stopping;
    expect(e.state, BotState.locked);
    expect((await e.submit('blocked')).state, OrderState.rejected);
  });

  test('emergency during reservation save prevents submission', () async {
    final gate = Completer<void>();
    var saving = false;
    final e = make(
      save: (raw) async {
        if (raw.contains('risk reserved')) {
          saving = true;
          await gate.future;
        }
      },
    );
    await e.start();
    final pending = e.submit('a');
    await Future<void>.delayed(Duration.zero);
    expect(saving, true);
    final stop = e.emergencyStop();
    gate.complete();
    await pending;
    await stop;
    expect(e.orders.single.state, OrderState.cancelled);
    expect(e.state, BotState.locked);
  });
}
