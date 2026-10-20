import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_theme.dart';

class HawuPayLogo extends StatelessWidget {
  const HawuPayLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .2),
        child: SvgPicture.asset(
          'assets/brand/hawupay-logo.svg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
}

class TenunBrandBorder extends StatelessWidget {
  const TenunBrandBorder({super.key, this.height = 6});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TenunBorderPainter()),
      );
}

class _TenunBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [TW.red, TW.gold, TW.navy, TW.gold];
    final paint = Paint();
    for (var x = 0.0, index = 0; x < size.width; x += 8, index++) {
      paint.color = colors[index % colors.length];
      canvas.drawRect(Rect.fromLTWH(x, 0, 8, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TenunBorderPainter oldDelegate) => false;
}
