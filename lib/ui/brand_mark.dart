import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Temporary text placeholder; not a replacement logo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tipkhun Capital — placeholder รอโลโก้ต้นฉบับ',
    textDirection: TextDirection.ltr,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: CapitalMarkPainter()),
    ),
  );
}

class CapitalMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Neutral temporary placeholder pending the owner's original T logo.
    final text = TextPainter(
      text: const TextSpan(
        text: 'TC',
        style: TextStyle(
          color: charcoal,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
  }

  @override
  bool shouldRepaint(CapitalMarkPainter oldDelegate) => false;
}
