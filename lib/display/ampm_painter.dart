import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Letter outlines in a 1 by 1 box, as strokes.
Path _letterPath(String letter, Rect box) {
  Offset at(double x, double y) => Offset(box.left + box.width * x, box.top + box.height * y);
  final path = Path();
  switch (letter) {
    case 'A':
      path
        ..moveTo(at(0, 1).dx, at(0, 1).dy)
        ..lineTo(at(0.5, 0).dx, at(0.5, 0).dy)
        ..lineTo(at(1, 1).dx, at(1, 1).dy)
        ..moveTo(at(0.2, 0.68).dx, at(0.2, 0.68).dy)
        ..lineTo(at(0.8, 0.68).dx, at(0.8, 0.68).dy);
    case 'M':
      path
        ..moveTo(at(0, 1).dx, at(0, 1).dy)
        ..lineTo(at(0, 0).dx, at(0, 0).dy)
        ..lineTo(at(0.5, 0.6).dx, at(0.5, 0.6).dy)
        ..lineTo(at(1, 0).dx, at(1, 0).dy)
        ..lineTo(at(1, 1).dx, at(1, 1).dy);
    case 'P':
      path
        ..moveTo(at(0, 1).dx, at(0, 1).dy)
        ..lineTo(at(0, 0).dx, at(0, 0).dy)
        ..lineTo(at(0.6, 0).dx, at(0.6, 0).dy)
        ..quadraticBezierTo(at(1, 0).dx, at(1, 0).dy, at(1, 0.28).dx, at(1, 0.28).dy)
        ..quadraticBezierTo(at(1, 0.56).dx, at(1, 0.56).dy, at(0.6, 0.56).dx, at(0.6, 0.56).dy)
        ..lineTo(at(0, 0.56).dx, at(0, 0.56).dy);
  }
  return path;
}

/// Paints the letters AM above PM. The one that is true now is lit, the other is dim.
class AmPmPainter extends CustomPainter {
  const AmPmPainter({required this.isPm, this.lit = AppColors.digitLit});

  final bool isPm;
  final Color lit;

  @override
  void paint(Canvas canvas, Size size) {
    final letterHeight = size.height * 0.2;
    final stroke = letterHeight * 0.17;
    final letterWidth = letterHeight * 0.62;
    final letterGap = letterHeight * 0.28;
    final rowWidth = letterWidth * 2 + letterGap;
    final rowGap = letterHeight * 0.7;
    final left = (size.width - rowWidth) / 2;
    final blockHeight = letterHeight * 2 + rowGap;
    final top = (size.height - blockHeight) / 2;

    void row(String first, String second, double y, bool on) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.miter;
      for (var i = 0; i < 2; i++) {
        final letter = i == 0 ? first : second;
        final x = left + i * (letterWidth + letterGap);
        // Keep the stroke inside the letter's box.
        final box = Rect.fromLTWH(x, y, letterWidth, letterHeight).deflate(stroke / 2);
        final path = _letterPath(letter, box);
        if (on) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..color = lit.withValues(alpha: 0.55)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.4),
          );
          canvas.drawPath(path, strokePaint..color = lit);
        } else {
          canvas.drawPath(
            path,
            strokePaint..color = lit.withValues(alpha: AppColors.digitUnlitOpacity),
          );
        }
      }
    }

    row('A', 'M', top, !isPm);
    row('P', 'M', top + letterHeight + rowGap, isPm);
  }

  @override
  bool shouldRepaint(AmPmPainter old) => old.isPm != isPm || old.lit != lit;
}
