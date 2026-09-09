import 'package:flutter/material.dart';

/// The original Tipkhun artwork, framed around its symbol without altering it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'โลโก้ Tipkhun Capital',
    image: true,
    textDirection: TextDirection.ltr,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: Colors.white,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: size * 2.45,
              maxHeight: size * 2.45,
              child: Transform.translate(
                offset: Offset(0, size * .25),
                child: Image.asset(
                  'assets/tipkhun-logo.png',
                  width: size * 2.45,
                  height: size * 2.45,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
