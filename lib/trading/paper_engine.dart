import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../domain/investment_plan.dart';

enum OrderState {
  created,
  riskChecked,
  submitted,
  acknowledged,
  partiallyFilled,
  filled,
  closing,
  closed,
  rejected,
  cancelled,
  expired,
  unknown,
}

enum BotState { ready, active, paused, stopped, locked }

/// Fully funded, long-only synthetic instrument. No market feed or live endpoint.
class PaperOrder {
  PaperOrder(this.id, this.quantity, this.limit, this.created);
  final String id;
  final int quantity, limit;
  final DateTime created;
  OrderState state = OrderState.created;
  int filled = 0;
  int? exit;
  DateTime? closedAt;
  String? reason;
  int get reserved => switch (state) {
    OrderState.closed ||
    OrderState.rejected ||
    OrderState.cancelled ||
    OrderState.expired => 0,
    _ => quantity * limit,
  };
  int get pnl => exit == null ? 0 : filled * (exit! - limit);
  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'limit': limit,
    'created': created.toUtc().toIso8601String(),
    'state': state.name,
    'filled': filled,
    'exit': exit,
    'closedAt': closedAt?.toUtc().toIso8601String(),
    'reason': reason,
  };
  factory PaperOrder.fromJson(Map<String, dynamic> j) {
    final o = PaperOrder(
      j['id'],
      j['quantity'],
      j['limit'],
      DateTime.parse(j['created']),
    );
    o.state = OrderState.values.byName(j['state']);
    o.filled = j['filled'];
    o.exit = j['exit'];
    o.closedAt = j['closedAt'] == null ? null : DateTime.parse(j['closedAt']);
    o.reason = j['reason'];
    if (o.quantity <= 0 ||
        o.limit <= 0 ||
        o.filled < 0 ||
        o.filled > o.quantity) {
      throw const FormatException('Invalid order');
    }
    return o;
  }
}

abstract interface class BrokerAdapter {
  String get environment;
  bool get connected;
  DateTime get marketTime;
  Future<void> connect();
  Future<void> disconnect();
  Future<int> placeOrder(String id, int quantity, int limit);
  Future<int?> reconcile(String id);
  Future<void> cancelOrder(String id);
  Future<int> closePosition(String id);
}

abstract interface class PaperBrokerAdapter implements BrokerAdapter {}

// No live implementation, credential parser, or live execution factory exists.
abstract interface class LiveBrokerAdapter implements BrokerAdapter {}

class MockBrokerAdapter implements PaperBrokerAdapter {
  MockBrokerAdapter({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  final Map<String, int> _fills = {};
  final Map<String, int> _prices = {};
  @override
  String get environment => 'paper-local-synthetic';
  @override
  bool connected = false;
  @override
  DateTime get marketTime => clock().toUtc();
  @override
  Future<void> connect() async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<int> placeOrder(String id, int quantity, int limit) async {
    if (!connected) throw StateError('Disconnected');
    _prices.putIfAbsent(id, () => limit);
    return _fills.putIfAbsent(id, () => quantity);
  }

  @override
  Future<int?> reconcile(String id) async => _fills[id];
  @override
  Future<void> cancelOrder(String id) async {
    if (!connected) throw StateError('Disconnected');
  }

  @override
  Future<int> closePosition(String id) async {
    if (!connected || !_prices.containsKey(id)) {
      throw StateError('Reconciliation required');
    }
    return _prices[id]!; // Explicit flat synthetic fill; no invented return.
  }
}

typedef SavePaper = Future<void> Function(String snapshot);

/// One serialized gateway per account. Snapshots persist before external effects.
/// This local simulator is not a server or a multi-process transaction store.
class PaperEngine {
  PaperEngine({
    required InvestmentPlan plan,
    required this.broker,
    required this.save,
    DateTime Function()? clock,
  }) : plan = InvestmentPlan.fromJson(plan.toJson()),
       clock = clock ?? DateTime.now {
    if (broker.environment != 'paper-local-synthetic' ||
        broker is! PaperBrokerAdapter) {
      throw ArgumentError('Paper adapter required');
    }
  }
  final InvestmentPlan plan;
  final BrokerAdapter broker;
  final SavePaper save;
  final DateTime Function() clock;
  final List<PaperOrder> _orders = [];
  final List<Map<String, dynamic>> _events = [];
  List<PaperOrder> get orders =>
      List.unmodifiable(_orders.map((o) => PaperOrder.fromJson(o.toJson())));
  List<Map<String, dynamic>> get events =>
      List.unmodifiable(_events.map(Map<String, dynamic>.unmodifiable));
  BotState _state = BotState.ready;
  BotState get state => _state;
  String? reason;
  Future<void> _tail = Future.value();
  bool _emergency = false;
  int get reserved => _orders.fold(0, (s, o) => s + o.reserved);
  int get losses => _orders
      .where((o) => o.closedAt != null && _day(o.closedAt!) == _day(clock()))
      .fold(0, (s, o) => s + max(0, -o.pnl));
  int get remaining =>
      max(0, min(plan.budget, plan.dailyLossLimit) - losses - reserved);
  int get pnl => _orders.fold(0, (s, o) => s + o.pnl);
  String _day(DateTime t) => t
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 10);
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _persist(String event) async {
    _events.add({'time': clock().toUtc().toIso8601String(), 'event': event});
    try {
      await save(snapshot());
    } catch (_) {
      _state = BotState.locked;
      reason = 'Storage failure';
      rethrow;
    }
  }

  String snapshot() => jsonEncode({
    'version': 1,
    'environment': broker.environment,
    'plan': plan.toJson(),
    'state': state.name,
    'reason': reason,
    'orders': _orders.map((o) => o.toJson()).toList(),
    'events': _events,
  });
  static PaperEngine restore(
    String raw,
    BrokerAdapter broker,
    SavePaper save, {
    DateTime Function()? clock,
  }) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1 || j['environment'] != broker.environment) {
      throw const FormatException('Unsupported paper data');
    }
    final e = PaperEngine(
      plan: InvestmentPlan.fromJson(j['plan']),
      broker: broker,
      save: save,
      clock: clock,
    );
    e._orders.addAll((j['orders'] as List).map((o) => PaperOrder.fromJson(o)));
    if (e._orders.map((o) => o.id).toSet().length != e._orders.length) {
      throw const FormatException('Duplicate IDs');
    }
    e._events.addAll(
      (j['events'] as List).map((v) => Map<String, dynamic>.from(v)),
    );
    e._state = BotState.values.byName(j['state']) == BotState.locked
        ? BotState.locked
        : BotState.paused;
    e.reason = 'Restored; reconcile before resuming';
    if (broker is MockBrokerAdapter) {
      for (final o in e._orders.where(
        (o) =>
            o.state == OrderState.filled ||
            o.state == OrderState.partiallyFilled ||
            o.state == OrderState.acknowledged,
      )) {
        broker._fills[o.id] = o.filled;
        broker._prices[o.id] = o.limit;
      }
    }
    return e;
  }

  Future<void> start() => _serial(() async {
    if (_emergency ||
        state == BotState.locked ||
        _orders.any((o) => o.reserved > 0)) {
      throw StateError('Locked or unresolved positions');
    }
    await broker.connect();
    if (_emergency) {
      _state = BotState.locked;
      await _persist('Start interrupted by emergency');
      return;
    }
    _state = BotState.active;
    reason = null;
    await _persist('Bot started: paper');
  });
  Future<void> pause() => _serial(() async {
    if (state != BotState.locked) _state = BotState.paused;
    await _persist('Paused');
  });
  Future<void> stop() => _serial(() async {
    if (state != BotState.locked) _state = BotState.stopped;
    await _persist('Stopped; positions retained');
  });
  Future<void> emergencyStop() {
    _emergency = true;
    _state = BotState.locked;
    reason = 'Emergency stop';
    return _serial(() async {
      _state = BotState.locked;
      await _persist('Emergency stop; block entries; retain open positions');
      for (final o in _orders.where(
        (o) => o.reserved > 0 && o.filled < o.quantity,
      )) {
        try {
          await broker.cancelOrder(o.id);
          await _reconcile(o);
        } catch (_) {
          o.state = OrderState.unknown;
        }
      }
      await _persist('Emergency pending-order review completed');
    });
  }

  Future<PaperOrder> submit(String id, {int quantity = 1, int limit = 100}) =>
      _serial(() async {
        for (final o in _orders) {
          if (o.id == id) {
            if (o.quantity != quantity || o.limit != limit) {
              throw ArgumentError('Idempotency conflict');
            }
            return PaperOrder.fromJson(o.toJson());
          }
        }
        if (id.trim().isEmpty ||
            quantity <= 0 ||
            limit <= 0 ||
            quantity > 1000000 ||
            limit > 1000000) {
          throw ArgumentError('Invalid order');
        }
        final o = PaperOrder(id, quantity, limit, clock().toUtc());
        final marketTime = broker.marketTime;
        final age = clock().toUtc().difference(marketTime);
        final count = _orders
            .where(
              (o) =>
                  _day(o.created) == _day(clock()) &&
                  o.state != OrderState.rejected,
            )
            .length;
        final risk =
            quantity * limit; // Full notional reserved, price can fall to zero.
        final dayRecords = _orders
            .where(
              (o) =>
                  o.closedAt != null &&
                  _day(o.closedAt!) == _day(clock()) &&
                  o.state == OrderState.closed,
            )
            .map((o) => TradeRecord('SYNTHETIC-THB', o.pnl, o.created, false))
            .toList();
        final planStop = plan.reasonFor(dayRecords);
        final denied = _emergency || state != BotState.active
            ? 'Bot inactive'
            : !broker.connected
            ? 'Broker disconnected'
            : age.isNegative || age > const Duration(seconds: 30)
            ? 'Stale market data'
            : planStop ??
                  (count >= plan.maxTrades
                      ? 'Trade limit'
                      : risk > plan.riskPerTrade ||
                            risk > remaining ||
                            reserved + risk > plan.capital + min(0, pnl)
                      ? 'Risk limit'
                      : _orders.any((o) => o.reserved > 0)
                      ? 'Maximum open positions: 1'
                      : null);
        _orders.add(o);
        if (denied != null) {
          o.state = OrderState.rejected;
          o.reason = denied;
          await _persist('$id rejected: $denied');
          return PaperOrder.fromJson(o.toJson());
        }
        o.state = OrderState.riskChecked;
        await _persist('$id risk reserved');
        if (_emergency) {
          o.state = OrderState.cancelled;
          await _persist('$id cancelled before submission');
          return PaperOrder.fromJson(o.toJson());
        }
        o.state = OrderState.submitted;
        await _persist('$id submitted intent');
        if (_emergency) {
          o.state = OrderState.cancelled;
          await _persist('$id cancelled before broker call');
          return PaperOrder.fromJson(o.toJson());
        }
        try {
          final filled = await broker
              .placeOrder(id, quantity, limit)
              .timeout(const Duration(seconds: 5));
          _applyFill(o, filled);
        } catch (_) {
          o.state = OrderState.unknown;
          _state = BotState.locked;
          reason = 'Reconciliation required';
        }
        await _persist('$id ${o.state.name}');
        return PaperOrder.fromJson(o.toJson());
      });
  void _applyFill(PaperOrder o, int filled) {
    if (filled < o.filled || filled > o.quantity) {
      throw StateError('Invalid fill');
    }
    o.filled = filled;
    o.state = filled == o.quantity
        ? OrderState.filled
        : filled == 0
        ? OrderState.acknowledged
        : OrderState.partiallyFilled;
  }

  Future<void> _reconcile(PaperOrder o) async {
    if (o.state == OrderState.closing ||
        o.reason == 'Close reconciliation required') {
      o.state = OrderState.unknown;
      o.reason = 'Close reconciliation required';
      return;
    }
    final filled = await broker
        .reconcile(o.id)
        .timeout(const Duration(seconds: 5));
    if (filled == null) {
      o.state = OrderState.unknown;
      return;
    }
    _applyFill(o, filled);
  }

  Future<void> reconcile() => _serial(() async {
    await broker.connect();
    for (final o in _orders.where((o) => o.reserved > 0)) {
      await _reconcile(o);
    }
    await _persist('Reconciliation; no automatic resubmission');
  });
  Future<void> close(String id) => _serial(() async {
    final o = _orders.singleWhere((o) => o.id == id);
    if (o.state == OrderState.closed) return;
    if (o.state != OrderState.filled) {
      throw StateError('Reconcile before closing');
    }
    o.state = OrderState.closing;
    await _persist('$id closing intent');
    try {
      final price = await broker
          .closePosition(id)
          .timeout(const Duration(seconds: 5));
      if (price < 0) throw StateError('Invalid exit');
      o.exit = price;
      o.closedAt = clock().toUtc();
      o.state = OrderState.closed;
    } catch (_) {
      o.state = OrderState.unknown;
      o.reason = 'Close reconciliation required';
      _state = BotState.locked;
      reason = 'Close reconciliation required';
    }
    if (remaining == 0 && state != BotState.locked) {
      _state = BotState.stopped;
      reason = 'Loss limit';
    }
    await _persist('$id ${o.state.name}');
  });
}
