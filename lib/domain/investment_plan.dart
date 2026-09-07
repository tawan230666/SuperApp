import 'dart:math';

/// Money uses integer satang; percentages use basis points.
class InvestmentPlan {
  InvestmentPlan({
    this.capital = 35000,
    this.dailyRate = 500,
    this.riskPerTrade = 500,
    this.target = 3000,
    int? dailyLossLimit,
    int? maximumTrades,
    this.riskLevel = 'Medium',
    this.cycle = 'Daily',
    DateTime Function()? clock,
  }) : dailyLossLimit = dailyLossLimit ?? capital * dailyRate ~/ 10000,
       maxTrades =
           maximumTrades ??
           (capital * dailyRate ~/ 10000) ~/ max(1, riskPerTrade),
       clock = clock ?? DateTime.now {
    if (capital <= 0 ||
        dailyRate <= 0 ||
        dailyRate > 10000 ||
        riskPerTrade <= 0 ||
        riskPerTrade > capital ||
        target <= 0 ||
        this.dailyLossLimit <= 0 ||
        this.dailyLossLimit > capital ||
        maxTrades < 0 ||
        !['Low', 'Medium', 'High', 'Custom'].contains(riskLevel) ||
        !['Daily', 'Weekly', 'Monthly'].contains(cycle)) {
      throw ArgumentError('Invalid plan');
    }
  }
  final DateTime Function() clock;
  final int capital, dailyRate, riskPerTrade, target, dailyLossLimit, maxTrades;
  final String riskLevel, cycle;
  final List<TradeRecord> _trades = [];
  final List<Allocation> allocations = [];
  List<TradeRecord> get trades => List.unmodifiable(_trades);
  int shortPercent = 50, longPercent = 30, withdrawPercent = 20;
  int get allocated => allocations.fold(0, (s, a) => s + a.amount);
  int get reinvestment => allocations.fold(0, (s, a) => s + a.short);
  int get longTerm => allocations.fold(0, (s, a) => s + a.long);
  int get withdrawal => allocations.fold(0, (s, a) => s + a.withdraw);
  int get budget => capital * dailyRate ~/ 10000;
  List<TradeRecord> onDay(DateTime day) =>
      _trades.where((t) => sameDay(t.time, day)).toList();
  List<TradeRecord> get today => onDay(clock());
  int get pnl => today.fold(0, (s, t) => s + t.net);
  int get totalPnl => trades.fold(0, (s, t) => s + t.net);
  int get losses => today.fold(0, (s, t) => s + max(0, -t.net));
  int get remaining => max(0, budget - losses);
  int get tradesLeft => max(
    0,
    min(
      maxTrades - today.length,
      min(remaining, max(0, dailyLossLimit - losses)) ~/ riskPerTrade,
    ),
  );
  int get distributable =>
      max(0, min(totalPnl - allocated, capital + totalPnl - allocated));
  String get tradingStatus => losses >= dailyLossLimit || losses >= budget
      ? 'STOP'
      : pnl >= target
      ? 'TARGET_REACHED'
      : stopReason != null
      ? 'STOP'
      : 'ACTIVE';
  String? get stopReason => reasonFor(today);
  String? reasonFor(List<TradeRecord> records) {
    int net = 0, loss = 0;
    String? reason;
    for (final t in records) {
      net += t.net;
      loss += max(0, -t.net);
      if (loss >= dailyLossLimit || loss >= budget) {
        reason = 'ถึงขีดจำกัดความเสี่ยงของวันนี้แล้ว';
      } else if (reason == null && net >= target) {
        reason = 'ถึงเป้าหมายของวันนี้แล้ว พิจารณาหยุดเพื่อรักษากำไร';
      }
    }
    if (reason != null) return reason;
    if (records.length >= maxTrades) return 'ครบจำนวนเทรดตามแผนแล้ว';
    if (min(budget - loss, dailyLossLimit - loss) < riskPerTrade) {
      return 'งบคงเหลือไม่พอสำหรับเทรดถัดไป';
    }
    return null;
  }

  void record(
    String asset,
    int gross, {
    int fees = 0,
    DateTime? time,
    String note = '',
    String strategy = '',
  }) {
    final date = time ?? clock();
    if (asset.trim().isEmpty || fees < 0 || date.isAfter(clock())) {
      throw ArgumentError('Invalid trade');
    }
    _trades.add(
      TradeRecord(
        asset.trim(),
        gross - fees,
        date,
        false,
        fees: fees,
        note: note,
        strategy: strategy,
      ),
    );
    _trades.sort((a, b) => a.time.compareTo(b.time));
    // Replay in chronological order so backdated entries cannot evade discipline rules.
    for (var i = 0; i < _trades.length; i++) {
      final t = _trades[i];
      final prior = _trades
          .take(i)
          .where((p) => sameDay(p.time, t.time))
          .toList();
      _trades[i] = TradeRecord(
        t.asset,
        t.net,
        t.time,
        reasonFor(prior) != null || max(0, -t.net) > riskPerTrade,
        fees: t.fees,
        note: t.note,
        strategy: t.strategy,
      );
    }
  }

  void setAllocation(int short, int long, int withdraw) {
    if ([short, long, withdraw].any((p) => p < 0 || p > 100) ||
        short + long + withdraw != 100) {
      throw ArgumentError('Percentages must total 100');
    }
    shortPercent = short;
    longPercent = long;
    withdrawPercent = withdraw;
  }

  Allocation preview() {
    final amount = distributable;
    final short = amount * shortPercent ~/ 100,
        long = amount * longPercent ~/ 100;
    return Allocation(clock(), amount, short, long, amount - short - long);
  }

  void allocate() {
    if (distributable > 0) allocations.add(preview());
  }

  List<RiskDay> get history => List.generate(30, (i) {
    final now = clock();
    final date = DateTime(now.year, now.month, now.day - i);
    final entries = onDay(date);
    return RiskDay(date, entries, budget);
  });
  Map<String, dynamic> toJson() => {
    'version': 1,
    'capital': capital,
    'dailyRate': dailyRate,
    'riskPerTrade': riskPerTrade,
    'target': target,
    'dailyLossLimit': dailyLossLimit,
    'maximumTrades': maxTrades,
    'riskLevel': riskLevel,
    'cycle': cycle,
    'ratios': [shortPercent, longPercent, withdrawPercent],
    'trades': trades.map((t) => t.toJson()).toList(),
    'allocations': allocations.map((a) => a.toJson()).toList(),
  };
  factory InvestmentPlan.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported data version');
    }
    final p = InvestmentPlan(
      capital: j['capital'],
      dailyRate: j['dailyRate'],
      riskPerTrade: j['riskPerTrade'],
      target: j['target'],
      dailyLossLimit: j['dailyLossLimit'],
      maximumTrades: j['maximumTrades'],
      riskLevel: j['riskLevel'],
      cycle: j['cycle'],
    );
    final r = j['ratios'] as List;
    p.setAllocation(r[0], r[1], r[2]);
    for (final t in j['trades']) {
      p._trades.add(
        TradeRecord(
          t['asset'],
          t['net'],
          DateTime.parse(t['time']).toLocal(),
          t['outsidePlan'],
          fees: t['fees'],
          note: t['note'],
          strategy: t['strategy'],
        ),
      );
    }
    for (final a in j['allocations']) {
      p.allocations.add(
        Allocation(
          DateTime.parse(a['time']).toLocal(),
          a['amount'],
          a['short'],
          a['long'],
          a['withdraw'],
        ),
      );
    }
    return p;
  }
}

class TradeRecord {
  const TradeRecord(
    this.asset,
    this.net,
    this.time,
    this.outsidePlan, {
    this.fees = 0,
    this.note = '',
    this.strategy = '',
  });
  final String asset, note, strategy;
  final int net, fees;
  final DateTime time;
  final bool outsidePlan;
  Map<String, dynamic> toJson() => {
    'asset': asset,
    'net': net,
    'time': time.toIso8601String(),
    'outsidePlan': outsidePlan,
    'fees': fees,
    'note': note,
    'strategy': strategy,
  };
}

class Allocation {
  const Allocation(
    this.time,
    this.amount,
    this.short,
    this.long,
    this.withdraw,
  );
  final DateTime time;
  final int amount, short, long, withdraw;
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'amount': amount,
    'short': short,
    'long': long,
    'withdraw': withdraw,
  };
}

class RiskDay {
  RiskDay(this.date, this.trades, this.budget);
  final DateTime date;
  final List<TradeRecord> trades;
  final int budget;
  int get loss => trades.fold(0, (s, t) => s + max(0, -t.net));
  int get violations => trades.where((t) => t.outsidePlan).length;
  int? get score => trades.isEmpty
      ? null
      : ((trades.length - violations) * 100 / trades.length).round();
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String money(int satang) => '฿${(satang / 100).toStringAsFixed(2)}';
String dateLabel(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
int? parseMoney(String input) {
  final value = input.trim();
  if (!RegExp(r'^-?\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceFirst('-', '').split('.');
  final amount =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return value.startsWith('-') ? -amount : amount;
}
