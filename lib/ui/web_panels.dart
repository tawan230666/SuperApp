import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/investment_plan.dart';
import '../state/paper_session.dart';
import 'app_shell.dart';
import 'workspace_widgets.dart';

class PanelGrid extends StatelessWidget {
  const PanelGrid({super.key, required this.children, this.minimumWidth = 360});
  final List<Widget> children;
  final double minimumWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = max(1, min(3, (c.maxWidth / minimumWidth).floor()));
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (c.maxWidth - (columns - 1) * 16) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class DataChart extends StatelessWidget {
  const DataChart({
    super.key,
    required this.title,
    required this.values,
    required this.description,
  });
  final String title, description;
  final List<int> values;
  @override
  Widget build(BuildContext context) => WorkspaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        Text(description, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        if (values.isEmpty)
          const SizedBox(
            height: 160,
            child: Center(child: Text('ยังไม่มีข้อมูลการเทรด')),
          )
        else ...[
          Text(
            'ต่ำสุด ${money(values.reduce(min))} • สูงสุด ${money(values.reduce(max))}',
            style: const TextStyle(fontSize: 12),
          ),
          Semantics(
            label:
                '$title เริ่ม ${money(values.first)} ล่าสุด ${money(values.last)}',
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _SeriesPainter(
                  values,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          Text(
            'เริ่ม ${money(values.first)} → ล่าสุด ${money(values.last)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter(this.values, this.color);
  final List<int> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final low = min(0, values.reduce(min)), high = max(0, values.reduce(max));
    final span = max(1, high - low);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = color.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 12 + (size.height - 24) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        values.length == 1
            ? size.width / 2
            : i * size.width / (values.length - 1),
        size.height - 12 - (values[i] - low) / span * (size.height - 24),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      if (values.length == 1) {
        canvas.drawCircle(point, 4, Paint()..color = color);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SeriesPainter old) =>
      old.values != values || old.color != color;
}

List<int> journalEquity(InvestmentPlan plan) {
  if (plan.trades.isEmpty) return [];
  var equity = plan.capital;
  return [equity, for (final t in plan.trades) equity += t.net];
}

List<int> journalDrawdown(InvestmentPlan plan) {
  var peak = plan.capital;
  return journalEquity(plan).map((e) {
    peak = max(peak, e);
    return e - peak;
  }).toList();
}

class AgentPanel extends StatelessWidget {
  const AgentPanel({super.key});
  @override
  Widget build(BuildContext context) => const WorkspaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Tipkhun AI Agent'),
        Text(
          'OFFLINE • ยังไม่เชื่อม AI Provider',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'งานวิเคราะห์: ยังไม่มี Agent Run\nStrategy: manual-synthetic-v1\nเหตุผลสรุป: ยังไม่มี AI Decision\nRisk Assessment: ตรวจด้วย deterministic engine\nBacktest: ยังไม่มีผลทดสอบ\nPaper Result: ดู Orders / P&L ในบอท',
        ),
        SizedBox(height: 12),
        Text(
          'ผู้ช่วยแชตใช้กฎจากข้อมูลในแอป ไม่ใช่ AI วิเคราะห์ตลาด',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class DashboardWebPanels extends StatelessWidget {
  const DashboardWebPanels({
    super.key,
    required this.plan,
    required this.paper,
    required this.onBot,
  });
  final InvestmentPlan plan;
  final PaperSession paper;
  final VoidCallback onBot;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DataChart(
        title: 'Recorded Equity Curve',
        values: journalEquity(plan),
        description:
            'ทุนตั้งต้น + ผลสุทธิจากบันทึก • ไม่ใช่ยอดโบรกเกอร์ ไม่รวมเงินฝาก/ถอนหรือมูลค่าตลาด',
      ),
      const SizedBox(height: 16),
      PanelGrid(
        children: [
          ListenableBuilder(
            listenable: paper,
            builder: (_, _) => WorkspaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Bot Status'),
                  Text(paper.engine?.state.name.toUpperCase() ?? 'ยังไม่พร้อม'),
                  Text(
                    paper.error ??
                        'Paper • Local Mock • ไม่มี worker เบื้องหลัง',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onBot,
                    child: const Text('เปิด Trading Bot'),
                  ),
                ],
              ),
            ),
          ),
          WorkspaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Profit Allocation'),
                Text('กำไรพร้อมจัดสรร ${money(plan.distributable)}'),
                const SizedBox(height: 12),
                AllocationBar(
                  values: [
                    plan.shortPercent,
                    plan.longPercent,
                    plan.withdrawPercent,
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'ระยะสั้น ${plan.shortPercent}% / ระยะยาว ${plan.longPercent}% / กันถอน ${plan.withdrawPercent}%',
                ),
              ],
            ),
          ),
          const AgentPanel(),
        ],
      ),
    ],
  );
}

class RiskAnalyticsPanel extends StatelessWidget {
  const RiskAnalyticsPanel({super.key, required this.plan});
  final InvestmentPlan plan;
  @override
  Widget build(BuildContext context) => ResponsivePageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Risk Analytics',
          subtitle: 'Simulation / Planning • อ้างอิงบันทึกในอุปกรณ์นี้',
        ),
        MetricGrid(
          children: [
            MetricCard(
              label: 'Risk Used วันนี้',
              value: money(plan.losses),
              icon: Icons.shield_outlined,
            ),
            MetricCard(
              label: 'Risk Remaining วันนี้',
              value: money(plan.remaining),
              icon: Icons.savings_outlined,
            ),
            MetricCard(
              label: 'Daily Loss Limit',
              value: money(plan.dailyLossLimit),
              icon: Icons.block,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PanelGrid(
          children: [
            DataChart(
              title: 'Daily P&L · 30 วัน',
              values: plan.trades.isEmpty
                  ? []
                  : plan.history.reversed
                        .map((d) => d.trades.fold<int>(0, (s, t) => s + t.net))
                        .toList(),
              description: 'กำไรสุทธิจากบันทึกตามวันบนอุปกรณ์',
            ),
            DataChart(
              title: 'Recorded Drawdown',
              values: journalDrawdown(plan),
              description:
                  'ผลต่างจากจุดสูงสุดของ Recorded Equity เป็นจำนวนเงิน ไม่ใช่ intraday market drawdown',
            ),
          ],
        ),
        const SizedBox(height: 20),
        WorkspaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Win / Loss Statistics'),
              if (plan.trades.isEmpty)
                const Text('ยังไม่มีข้อมูลการเทรด')
              else
                Text(
                  'กำไร ${plan.trades.where((t) => t.net > 0).length} • ขาดทุน ${plan.trades.where((t) => t.net < 0).length} • เท่าทุน ${plan.trades.where((t) => t.net == 0).length}\nนับจากกำไรสุทธิหลังค่าธรรมเนียม ไม่รับรองผลในอนาคต',
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ResearchPlaceholder extends StatelessWidget {
  const ResearchPlaceholder({
    super.key,
    required this.backtest,
    required this.onBack,
  });
  final bool backtest;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      SectionTitle(backtest ? 'Backtest Results' : 'Strategy Library'),
      const Text('Paper / Research • Coming Soon'),
      const SizedBox(height: 20),
      Text(
        backtest
            ? 'ยังไม่มี BacktestRun หรือข้อมูลย้อนหลัง จึงยังไม่มีผลตอบแทนหรือคะแนนให้แสดง'
            : 'manual-synthetic-v1 เป็นชุดคำสั่งทดลองด้วยตนเอง ยังไม่มี Strategy ที่ผ่านการทดสอบหรืออนุมัติ',
      ),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: onBack, child: const Text('กลับ Trading Bot')),
    ],
  );
}
