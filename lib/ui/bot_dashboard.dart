import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/investment_plan.dart';
import '../trading/paper_engine.dart';

class BotDashboard extends StatefulWidget {
  const BotDashboard({super.key, required this.plan});
  final InvestmentPlan plan;
  @override
  State<BotDashboard> createState() => _BotDashboardState();
}

class _BotDashboardState extends State<BotDashboard> {
  static const key = 'tipkhun.paper.synthetic.v1';
  PaperEngine? engine;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Future<void> save(String raw) async {
        if (!await prefs.setString(key, raw)) {
          throw StateError('Paper save failed');
        }
      }

      final raw = prefs.getString(key);
      final broker = MockBrokerAdapter();
      final e = raw == null
          ? PaperEngine(plan: widget.plan, broker: broker, save: save)
          : PaperEngine.restore(raw, broker, save);
      if (mounted) setState(() => engine = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'อ่านข้อมูล Paper ไม่ได้ ข้อมูลเดิมไม่ถูกเขียนทับ',
        );
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Scaffold(
      appBar: AppBar(title: const Text('Trading Bot')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tipkhun Capital · Paper Trading',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Mock Broker • SYNTHETIC-THB • ไม่มีเงินจริง\nราคาและผลจับคู่จำลองในเครื่อง ไม่ใช่ข้อมูลตลาด',
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (e == null && error == null) const LinearProgressIndicator(),
          if (e != null) ...[
            Text(
              'สถานะ: ${e.state.name} · ${e.broker.connected ? "Connected (Mock)" : "Disconnected"}',
            ),
            if (e.reason != null) Text(e.reason!),
            Text(
              'งบคงเหลือ ${money(e.remaining)} • กันความเสี่ยง ${money(e.reserved)}',
            ),
            Text('กำไรสุทธิจำลอง ${money(e.pnl)}'),
            const Text(
              'Strategy: manual-synthetic-v1\nแผน Paper เป็น snapshot ตอนเริ่ม ไม่แก้ประวัติแผนเดิม\nหนึ่ง position • ซื้อด้วยเงินเต็มจำนวน • ค่าธรรมเนียมจำลอง 0',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => run(e.start),
                  child: const Text('Start Paper'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => run(e.pause),
                  child: const Text('Pause'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => run(e.stop),
                  child: const Text('Stop'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => run(e.reconcile),
                  child: const Text('Reconcile'),
                ),
                FilledButton(
                  onPressed: busy || e.state != BotState.active
                      ? null
                      : () => run(() async {
                          await e.submit(
                            'paper-${DateTime.now().microsecondsSinceEpoch}',
                            limit: 100,
                          );
                        }),
                  child: const Text('ทดลองซื้อ 1 หน่วย ฿1'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => run(e.emergencyStop),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Emergency Stop'),
            ),
            const Text(
              'หยุดคำสั่งใหม่ทันที คง position ไว้ให้ตรวจสอบและปิดด้วยตนเอง ไม่รับประกันการปิดทันที\nตัวจำลองทำงานเมื่อสั่งในแอป ยังไม่มี worker เบื้องหลัง',
            ),
            const Divider(),
            const Text('Orders / Positions'),
            if (e.orders.isEmpty) const Text('ยังไม่มีคำสั่ง'),
            for (final o in e.orders.reversed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.id),
                      Text(
                        '${o.state.name} • ${o.filled}/${o.quantity} • ${money(o.limit)}',
                      ),
                      if (o.reason != null) Text(o.reason!),
                      if (o.state == OrderState.filled)
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => run(() => e.close(o.id)),
                          child: const Text('ปิดที่ราคาเดิม (จำลอง)'),
                        ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            const Text('Audit / Execution History (UTC)'),
            for (final event in e.events.reversed.take(30))
              Text('${event['time']} · ${event['event']}'),
          ],
        ],
      ),
    );
  }
}
