import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'design_tokens.dart';
export 'design_tokens.dart';

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.child,
    this.color = surface,
    this.padding = CapitalSpace.lg,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      gradient: color == charcoal
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [forest, charcoal],
            )
          : null,
      boxShadow: color == surface
          ? [
              BoxShadow(
                color: ink.withValues(alpha: .025),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
      border: Border.all(color: color == surface ? border : color),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Amount extends StatelessWidget {
  const Amount(this.value, {super.key, this.size = 30, this.color = ink});
  final String value;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      style: TextStyle(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
        height: 1.3,
        color: color,
      ),
    ),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = green,
    this.background = mint,
    this.size = 42,
  });
  final IconData icon;
  final Color color, background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, size: size * .48, color: color),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.dark = false,
    this.warning = false,
  });
  final String text;
  final bool dark, warning;
  @override
  Widget build(BuildContext context) {
    final fg = warning
        ? (dark ? const Color(0xFFFFD69A) : const Color(0xFF875E2B))
        : (dark ? lime : green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Actual risk consumption, not a market performance chart.
class RiskGauge extends StatelessWidget {
  const RiskGauge({super.key, required this.remaining, required this.limit});
  final int remaining, limit;
  @override
  Widget build(BuildContext context) {
    final fraction = limit == 0 ? 0.0 : (remaining / limit).clamp(0.0, 1.0);
    return Semantics(
      label: 'งบความเสี่ยงคงเหลือ ${(fraction * 100).round()} เปอร์เซ็นต์',
      child: SizedBox.square(
        dimension: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GaugePainter(fraction)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(fraction * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    color: lime,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'คงเหลือ',
                  style: TextStyle(fontSize: 10, color: railText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction);
  final double fraction;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      paint..color = const Color(0xFF425047),
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        paint..color = lime,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      fraction != oldDelegate.fraction;
}

class EmptyJournal extends StatelessWidget {
  const EmptyJournal({
    super.key,
    this.title = 'ยังไม่มีรายการเทรด',
    this.description =
        'รายการเทรดของคุณจะปรากฏที่นี่\nเริ่มบันทึกเพื่อทบทวนผลลัพธ์และวินัยในแต่ละวัน',
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        const IconBadge(Icons.receipt_long_outlined, size: 64),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 7),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.7),
        ),
      ],
    ),
  );
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final bool primary;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? green : surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 23,
              color: onTap == null
                  ? muted
                  : primary
                  ? Colors.white
                  : green,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null
                    ? muted
                    : primary
                    ? Colors.white
                    : ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Responsive metrics preserve reading order on compact screens.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 700 ? children.length : 2;
      final width = (c.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.valueColor = ink,
  });
  final String label, value;
  final String? detail;
  final IconData icon;
  final Color valueColor;
  @override
  Widget build(BuildContext context) => WorkspaceCard(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 6),
        Amount(value, size: 26, color: valueColor),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail!, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.message, {
    super.key,
    this.warning = false,
    this.icon = Icons.info_outline,
  });
  final String message;
  final bool warning;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF1EA) : mint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: warning ? negative : green, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: warning ? negative : forest,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class FormSection extends StatelessWidget {
  const FormSection(this.number, this.title, this.description, {super.key});
  final String number, title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: green,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AllocationBar extends StatelessWidget {
  const AllocationBar({super.key, required this.values});
  final List<int> values;
  static const colors = [green, Color(0xFF76B8A6), accent];
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'สัดส่วนระยะสั้น ${values[0]} เปอร์เซ็นต์ ระยะยาว ${values[1]} เปอร์เซ็นต์ ถอน ${values[2]} เปอร์เซ็นต์',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            if (values[i] > 0)
              Expanded(
                flex: values[i],
                child: Container(height: 12, color: colors[i]),
              ),
        ],
      ),
    ),
  );
}

class WorkspaceState extends StatelessWidget {
  const WorkspaceState({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String title, message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: WorkspaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                const IconBadge(Icons.cloud_off_outlined, size: 56),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
