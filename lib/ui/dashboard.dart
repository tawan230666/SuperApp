import 'package:flutter/material.dart';
import '../domain/investment_plan.dart';
import 'workspace_widgets.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.plan,
    required this.saving,
    required this.onConfigure,
    required this.onRecord,
    required this.onNavigate,
  });
  final InvestmentPlan plan;
  final bool saving;
  final VoidCallback onConfigure, onRecord;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 820;
      final left = Column(
        children: [
          _balance(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.add_rounded,
                  label: 'บันทึกเทรด',
                  onTap: saving ? null : onRecord,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.call_split_rounded,
                  label: 'จัดสรรกำไร',
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'ทบทวนแผน',
                  onTap: () => onNavigate(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _recent(),
        ],
      );
      final right = Column(
        children: [
          _today(),
          const SizedBox(height: 18),
          _nextStep(),
          const SizedBox(height: 18),
          _discipline(),
        ],
      );
      if (desktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: left),
            const SizedBox(width: 28),
            Expanded(flex: 5, child: right),
          ],
        );
      }
      return Column(
        children: [
          _balance(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.add_rounded,
                  label: 'บันทึกเทรด',
                  onTap: saving ? null : onRecord,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickAction(
                  icon: Icons.call_split_rounded,
                  label: 'จัดสรรกำไร',
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'ทบทวนแผน',
                  onTap: () => onNavigate(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _today(),
          const SizedBox(height: 20),
          _nextStep(),
          const SizedBox(height: 24),
          _recent(),
          const SizedBox(height: 20),
          _discipline(),
        ],
      );
    },
  );

  Widget _balance() => WorkspaceCard(
    color: charcoal,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'งบความเสี่ยงวันนี้',
                style: TextStyle(color: railText, fontSize: 13),
              ),
            ),
            StatusPill(
              plan.stopReason == null ? 'อยู่ในแผน' : 'พักการเทรด',
              dark: true,
              warning: plan.stopReason != null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'งบเสี่ยงคงเหลือ',
                      style: TextStyle(color: railText, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Amount(
                      money(plan.remaining),
                      size: 44,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'จากงบ ${money(plan.budget)}',
                      style: const TextStyle(color: railText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth >= 280) ...[
                const SizedBox(width: 12),
                RiskGauge(remaining: plan.remaining, limit: plan.budget),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF425047), height: 1),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _smallStat(
                'เงินตั้งต้น',
                money(plan.capital),
                Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _smallStat(
                'กำไร / ขาดทุนวันนี้',
                money(plan.pnl),
                plan.pnl < 0 ? const Color(0xFFFFB5AA) : lime,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _smallStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: railText)),
      const SizedBox(height: 5),
      Amount(value, size: 22, color: color),
    ],
  );

  Widget _today() => WorkspaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'ขอบเขตของวันนี้',
          subtitle: 'รู้จุดหยุด ก่อนเริ่มเทรด',
          action: const IconBadge(Icons.tune_rounded, size: 36),
        ),
        if (plan.stopReason != null) ...[
          Text(
            plan.stopReason!,
            style: const TextStyle(color: negative, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],
        _meter('ความเสี่ยงที่ใช้', plan.losses, plan.budget, green),
        _meter(
          'ขีดจำกัดขาดทุน',
          plan.losses,
          plan.dailyLossLimit,
          const Color(0xFFB99B73),
        ),
        _meter(
          'เป้าหมายกำไร',
          plan.pnl.clamp(0, plan.target),
          plan.target,
          const Color(0xFF7C9292),
        ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(child: _detail('ต่อเทรด', money(plan.riskPerTrade))),
            Expanded(child: _detail('เทรดได้อีก', '${plan.tradesLeft} ครั้ง')),
          ],
        ),
      ],
    ),
  );

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ],
  );

  Widget _meter(String label, int used, int max, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${money(used)} / ${money(max)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: max == 0 ? 0 : (used / max).clamp(0, 1),
          color: color,
          backgroundColor: const Color(0xFFEAEDE6),
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );

  Widget _nextStep() => WorkspaceCard(
    color: const Color(0xFFE6EAD9),
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.explore_outlined, size: 19, color: green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ก้าวต่อไปของคุณ',
                style: TextStyle(
                  fontSize: 12,
                  color: green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          plan.trades.isEmpty
              ? 'เริ่มด้วยแผนที่เป็นของคุณ'
              : plan.distributable > 0
              ? 'ให้กำไรไปถึงเป้าหมาย'
              : 'ทบทวนก่อนเริ่มครั้งถัดไป',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          plan.trades.isEmpty
              ? 'ตรวจเงินตั้งต้นและงบความเสี่ยงให้ตรงกับคุณ ก่อนบันทึกเทรดแรก'
              : plan.distributable > 0
              ? 'มีกำไรพร้อมจัดสรร ${money(plan.distributable)} เลือกแบ่งให้แต่ละเป้าหมายได้แล้ว'
              : 'ผู้ช่วยอธิบายสถานะจากข้อมูลที่คุณบันทึกไว้ได้',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: saving
                ? null
                : plan.trades.isEmpty
                ? onConfigure
                : () => onNavigate(plan.distributable > 0 ? 2 : 4),
            child: Text(
              plan.trades.isEmpty
                  ? 'ตั้งค่าแผนของฉัน'
                  : plan.distributable > 0
                  ? 'ไปแบ่งกำไร'
                  : 'เปิดผู้ช่วย',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _recent() => WorkspaceCard(
    child: Column(
      children: [
        SectionTitle(
          'กิจกรรมล่าสุด',
          subtitle: 'ทุกบันทึก คือข้อมูลสำหรับวันต่อไป',
          action: IconButton(
            tooltip: 'ดูบันทึกทั้งหมด',
            onPressed: () => onNavigate(1),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ),
        if (plan.trades.isEmpty) const EmptyJournal(),
        ...plan.trades.reversed
            .take(4)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    IconBadge(
                      t.net < 0 ? Icons.south_east : Icons.north_east,
                      color: t.net < 0 ? negative : green,
                      background: t.net < 0 ? const Color(0xFFF4E5E0) : mint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.asset,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            dateLabel(t.time),
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Amount(
                        money(t.net),
                        size: 18,
                        color: t.net < 0 ? negative : green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (plan.trades.isEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onRecord,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('บันทึกผลเทรด'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _discipline() => WorkspaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'วินัยในการเทรด',
          subtitle: 'วัดการทำตามแผน ไม่ใช่ความสามารถทำกำไร',
        ),
        Row(
          children: [
            const IconBadge(
              Icons.verified_outlined,
              background: Color(0xFFF0EBDF),
              color: accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                plan.history.first.score == null
                    ? 'ยังไม่มีคะแนนวันนี้'
                    : '${plan.history.first.score} / 100',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text(
            'ดูประวัติความเสี่ยง 30 วัน',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            Text(
              'ใช้ความเสี่ยงรวม ${money(plan.history.fold(0, (s, d) => s + d.loss))}',
              style: const TextStyle(fontSize: 12),
            ),
            ...plan.history.map(
              (d) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${d.date.day}/${d.date.month}/${d.date.year}'),
                subtitle: Text(
                  'ใช้ ${money(d.loss)} • ฝืนแผน ${d.violations} เทรด',
                ),
                trailing: Text(d.score == null ? '—' : '${d.score}/100'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
