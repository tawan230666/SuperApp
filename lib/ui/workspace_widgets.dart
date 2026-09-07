import 'dart:math' as math;
import 'package:flutter/material.dart';

const ink = Color(0xFF242E2B), green = Color(0xFF286451);
const canvas = Color(0xFFF0F1ED), muted = Color(0xFF647068);
const mint = Color(0xFFE4EBE1), border = Color(0xFFE0E3DB);
const surface = Color(0xFFFCFCF9), forest = Color(0xFF193C31);
const accent = Color(0xFF957345), railText = Color(0xFFC0C9C2);
const charcoal = Color(0xFF202C27), lime = Color(0xFFD2E7A7);
const negative = Color(0xFFAA5149);

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.child,
    this.color = surface,
    this.padding = 24,
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
      borderRadius: BorderRadius.circular(24),
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
    this.title = 'บันทึกเล็ก ๆ เพื่อการตัดสินใจที่ดีขึ้น',
    this.description =
        'รายการเทรดของคุณจะปรากฏที่นี่\nเริ่มบันทึกเพื่อทบทวนผลลัพธ์และวินัยในแต่ละวัน',
  });
  final String title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Transform.rotate(
          angle: -.08,
          child: Container(
            width: 100,
            height: 82,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF0E6),
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long_outlined, color: green, size: 22),
                const SizedBox(height: 9),
                Container(height: 3, width: 55, color: const Color(0xFFC2CCBA)),
                const SizedBox(height: 6),
                Container(height: 3, width: 36, color: const Color(0xFFD5DCCF)),
              ],
            ),
          ),
        ),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 23, color: onTap == null ? muted : green),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null ? muted : ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
