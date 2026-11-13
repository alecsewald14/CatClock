import 'package:flutter/material.dart';

import 'theme.dart';

/// The app icon: a friendly cat face with two blue segment-style eyes, on a dark navy
/// square. It has no text so it stays clear when very small, and it is fully opaque
/// because iPhone icons may not have transparency.
class CatIconPainter extends CustomPainter {
  const CatIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset at(double x, double y) => Offset(size.width * x, size.height * y);
    double len(double v) => s * v;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.panel);

    final outline = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = len(0.022)
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()..color = AppColors.fur;

    // Ears.
    for (final side in const [0.0, 1.0]) {
      double mirror(double x) => side == 0 ? x : 1 - x;
      final ear = Path()
        ..moveTo(at(mirror(0.17), 0.52).dx, at(0.17, 0.52).dy)
        ..lineTo(at(mirror(0.22), 0.14).dx, at(0.22, 0.14).dy)
        ..lineTo(at(mirror(0.46), 0.28).dx, at(0.46, 0.28).dy)
        ..close();
      canvas.drawPath(ear, fur);
      canvas.drawPath(ear, outline);
      final inner = Path()
        ..moveTo(at(mirror(0.23), 0.44).dx, at(0.23, 0.44).dy)
        ..lineTo(at(mirror(0.26), 0.25).dx, at(0.26, 0.25).dy)
        ..lineTo(at(mirror(0.39), 0.32).dx, at(0.39, 0.32).dy)
        ..close();
      canvas.drawPath(inner, Paint()..color = AppColors.earInner);
    }

    // Head.
    final head = Rect.fromCenter(center: at(0.5, 0.58), width: len(0.74), height: len(0.62));
    canvas.drawOval(head, fur);
    canvas.drawOval(head, outline);

    // Muzzle.
    canvas.drawOval(
      Rect.fromCenter(center: at(0.5, 0.72), width: len(0.3), height: len(0.17)),
      Paint()..color = AppColors.furLight,
    );

    // Eyes: two rounded blue bars with a glow, like lit segments of the clock.
    for (final x in const [0.36, 0.64]) {
      final bar = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at(x, 0.54), width: len(0.085), height: len(0.2)),
        Radius.circular(len(0.03)),
      );
      canvas.drawRRect(
        bar,
        Paint()
          ..color = AppColors.digitLit.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, len(0.03)),
      );
      canvas.drawRRect(bar, Paint()..color = AppColors.digitLit);
    }

    // Nose.
    final nose = Path()
      ..moveTo(at(0.46, 0.66).dx, at(0.46, 0.66).dy)
      ..lineTo(at(0.54, 0.66).dx, at(0.54, 0.66).dy)
      ..lineTo(at(0.5, 0.71).dx, at(0.5, 0.71).dy)
      ..close();
    canvas.drawPath(nose, Paint()..color = AppColors.nose);
  }

  @override
  bool shouldRepaint(CatIconPainter oldDelegate) => false;
}
