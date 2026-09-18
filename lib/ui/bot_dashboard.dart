import 'package:flutter/material.dart';
import '../data/paper_repository.dart';
import '../domain/investment_plan.dart';
import '../state/paper_session.dart';
import '../trading/paper_engine.dart';
import 'app_shell.dart';
import 'web_panels.dart';
import 'workspace_widgets.dart';

class BotDashboard extends StatefulWidget {
  const BotDashboard({
    super.key,
    required this.plan,
    this.session,
    this.embedded = false,
    this.onNavigate,
  });
  final InvestmentPlan plan;
  final PaperSession? session;
  final bool embedded;
  final ValueChanged<int>? onNavigate;
  @override
  State<BotDashboard> createState() => _BotDashboardState();
}

class _BotDashboardState extends State<BotDashboard> {
  late final session = widget.session ?? PaperSession(LocalPaperRepository());
  bool confirming = false;
  @override
  void initState() {
    super.initState();
    if (session.engine == null && !session.loading) session.load(widget.plan);
  }

  @override
  void dispose() {
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  Future<void> emergency() async {
    if (confirming) return;
    confirming = true;
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Emergency Stop'),
        content: const Text(
          'ล็อกคำสั่งใหม่และตรวจ pending orders โดยคง position ให้ตรวจสอบ/ปิดด้วยตนเอง ไม่สามารถเริ่ม session ที่ล็อกกลับโดยอัตโนมัติ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันหยุดฉุกเฉิน'),
          ),
        ],
      ),
    );
    confirming = false;
    if (approved == true && mounted && session.engine != null) {
      await session.run(session.engine!.emergencyStop, emergency: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final e = session.engine;
      final body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ResponsivePageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  'Trading Bot',
                  subtitle: 'Tipkhun Capital · Paper Trading',
                ),
                const Notice(
                  'Mock Broker • SYNTHETIC-THB • ไม่มีเงินจริง\nราคาและผลจับคู่จำลองในเครื่อง ไม่ใช่ข้อมูลตลาด',
                ),
                const SizedBox(height: 16),
                if (session.error != null)
                  Text(
                    session.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (session.loading) const LinearProgressIndicator(),
                if (e == null && !session.loading)
                  OutlinedButton(
                    onPressed: () => session.load(widget.plan),
                    child: const Text('ลองโหลด Paper ใหม่'),
                  ),
                if (e != null) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(e.state.name.toUpperCase()),
                      const Text('Simulation / Paper • Live LOCKED'),
                      if (widget.onNavigate != null) ...[
                        TextButton(
                          onPressed: () => widget.onNavigate!(8),
                          child: const Text('Strategy Library'),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigate!(9),
                          child: const Text('Backtest Results'),
                        ),
                      ],
                    ],
                  ),
                  if (e.reason != null) Text(e.reason!),
                  const SizedBox(height: 16),
                  MetricGrid(
                    children: [
                      MetricCard(
                        label: 'Account Equity (จำลอง)',
                        value: money(e.plan.capital + e.pnl),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      MetricCard(
                        label: 'Daily P&L (Bangkok)',
                        value: money(
                          e.orders
                              .where(
                                (o) =>
                                    o.closedAt != null &&
                                    _day(o.closedAt!) == _day(DateTime.now()),
                              )
                              .fold(0, (s, o) => s + o.pnl),
                        ),
                        icon: Icons.show_chart,
                      ),
                      MetricCard(
                        label: 'Risk Used / Reserved',
                        value: '${money(e.losses)} / ${money(e.reserved)}',
                        icon: Icons.shield_outlined,
                      ),
                      MetricCard(
                        label: 'Risk Remaining',
                        value: money(e.remaining),
                        icon: Icons.savings_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: session.busy
                            ? null
                            : () => session.run(e.start),
                        child: const Text('Start Paper'),
                      ),
                      OutlinedButton(
                        onPressed: session.busy
                            ? null
                            : () => session.run(e.pause),
                        child: const Text('Pause'),
                      ),
                      OutlinedButton(
                        onPressed: session.busy
                            ? null
                            : () => session.run(e.stop),
                        child: const Text('Stop'),
                      ),
                      OutlinedButton(
                        onPressed: session.busy
                            ? null
                            : () => session.run(e.reconcile),
                        child: const Text('Reconcile'),
                      ),
                      FilledButton(
                        onPressed: session.busy || e.state != BotState.active
                            ? null
                            : () => session.run(() async {
                                await e.submit(
                                  'paper-${DateTime.now().microsecondsSinceEpoch}',
                                  limit: 100,
                                );
                              }),
                        child: const Text('ทดลองซื้อ 1 หน่วย ฿1'),
                      ),
                      FilledButton(
                        onPressed: emergency,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Emergency Stop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PanelGrid(
                    children: [
                      WorkspaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionTitle('Connection & Strategy'),
                            Text(
                              'Broker: ${e.broker.connected ? "Connected (Mock)" : "Disconnected"}\nStrategy: manual-synthetic\nVersion: v1\nMarket: SYNTHETIC-THB\nTimeframe: Manual / ไม่มีแท่งราคา\nLast Heartbeat: ไม่มี Server Worker\nLast Market Update: ไม่มี Market Feed\nตรวจสถานะในแอปล่าสุด (UTC): ${session.observedAt?.toIso8601String() ?? "—"}',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Daily limit ${money(e.plan.dailyLossLimit)}\nRisk / trade ${money(e.plan.riskPerTrade)}\nMaximum trades ${e.plan.maxTrades}\nหนึ่ง position • ไม่ใช้ leverage\nFees / spread จำลอง 0',
                            ),
                          ],
                        ),
                      ),
                      const AgentPanel(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionTitle(
                    'Orders / Positions',
                    subtitle:
                        'Open ${e.orders.where((o) => o.filled > 0 && o.reserved > 0).length} • Pending ${e.orders.where((o) => o.reserved > 0 && o.filled < o.quantity).length}',
                  ),
                  if (e.orders.isEmpty)
                    const EmptyJournal(
                      title: 'ยังไม่มีคำสั่ง',
                      description: 'ทดลองส่งคำสั่งผ่าน Paper Risk Gateway',
                    ),
                  PanelGrid(
                    children: [
                      for (final o in e.orders.reversed)
                        WorkspaceCard(
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
                                  onPressed: session.busy
                                      ? null
                                      : () => session.run(() => e.close(o.id)),
                                  child: const Text('ปิดที่ราคาเดิม (จำลอง)'),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  WorkspaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Audit / Execution History (UTC)'),
                        if (e.events.isEmpty) const Text('ยังไม่มีเหตุการณ์'),
                        for (final event in e.events.reversed.take(30))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('${event['time']} · ${event['event']}'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ตัวจำลองทำงานเมื่อสั่งในแอป ไม่มี worker เบื้องหลัง • Refresh จะ pause และต้อง reconcile position เดิม\nข้อมูลใน browser ไม่ใช่ risk enforcement สำหรับเงินจริง',
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      return widget.embedded
          ? body
          : Scaffold(
              appBar: AppBar(title: const Text('Trading Bot')),
              body: body,
            );
    },
  );
  String _day(DateTime time) => time
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 10);
}
