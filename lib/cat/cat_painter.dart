import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'walk_cycle.dart';

/// The cat is drawn on a 1000 by 900 sheet and scaled to fit whatever box it is given.
const double catSceneWidth = 1000;
const double catSceneHeight = 900;

/// Where the screen on the belly goes on that sheet.
const Rect catBellyRect = Rect.fromLTWH(20, 360, 960, 420);

Paint _fill(Color color) => Paint()..color = color;

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _shape(Canvas canvas, Path path, Color color) {
  canvas.drawPath(path, _fill(color));
  canvas.drawPath(path, _line(AppColors.outline, 8));
}

/// Draws a friendly cartoon cat, facing the viewer, stepping in place.
///
/// The belly is left clear: the screen with the time goes on top of it. The cat never
/// covers that screen, and the screen never moves, so the digits stay perfectly still
/// while the cat's feet, head, and tail move around it.
class CatPainter extends CustomPainter {
  CatPainter(this.pose) : super(repaint: pose);

  final ValueListenable<CatPose> pose;

  @override
  void paint(Canvas canvas, Size size) {
    final current = pose.value;
    canvas.save();
    canvas.scale(size.width / catSceneWidth, size.height / catSceneHeight);

    final angle = 2 * math.pi * current.phase;
    // -1 to 1: one foot is lifted while this is positive, the other while it is negative.
    final step = math.sin(angle);
    // The body rises a little at each step, up to 7 units, which is under 2% of its height.
    final bob = -step.abs() * 7;

    _shadow(canvas, bob);
    _tail(canvas, current.phase);
    _feet(canvas, step);

    canvas.save();
    canvas.translate(0, bob);
    _body(canvas);
    canvas.restore();

    canvas.save();
    canvas.translate(0, bob * 1.3);
    _head(canvas, current.phase, current.blink);
    canvas.restore();

    canvas.restore();
  }

  void _shadow(Canvas canvas, double bob) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(500, 889), width: 860 + bob * 3, height: 28),
      _fill(Colors.black.withValues(alpha: 0.4)),
    );
  }

  void _tail(Canvas canvas, double phase) {
    final sway = 0.2 * math.sin(2 * math.pi * phase + 1.0);
    canvas.save();
    canvas.translate(850, 430);
    canvas.rotate(sway);
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(70, -40, 80, -120, 30, -175)
      ..cubicTo(-10, -215, 10, -265, 50, -275);
    canvas.drawPath(path, _line(AppColors.outline, 62));
    canvas.drawPath(path, _line(AppColors.fur, 48));
    canvas.drawCircle(const Offset(50, -275), 24, _fill(AppColors.furDark));
    canvas.restore();
  }

  void _feet(Canvas canvas, double step) {
    for (final side in const [-1.0, 1.0]) {
      final x = 500 + side * 175;
      // The left foot lifts while step is positive, the right foot while it is negative.
      final lift = math.max(0.0, -side * step) * 28;
      final footY = 856 - lift;

      final leg = Path()
        ..addRRect(RRect.fromLTRBR(x - 62, 780, x + 62, footY, const Radius.circular(40)));
      _shape(canvas, leg, AppColors.fur);

      final foot = Path()..addOval(Rect.fromCenter(center: Offset(x, footY), width: 190, height: 82));
      _shape(canvas, foot, AppColors.furLight);

      final toes = _line(AppColors.outline, 5);
      canvas.drawLine(Offset(x - 26, footY + 12), Offset(x - 26, footY + 30), toes);
      canvas.drawLine(Offset(x + 26, footY + 12), Offset(x + 26, footY + 30), toes);
    }
  }

  void _body(Canvas canvas) {
    final body = Path()
      ..addRRect(RRect.fromLTRBR(4, 332, 996, 812, const Radius.circular(190)));
    _shape(canvas, body, AppColors.fur);

    // Stripes on the shoulders, visible either side of the head.
    final stripe = _line(AppColors.furDark, 15);
    for (final side in const [0.0, 1.0]) {
      double mirror(double x) => side == 0 ? x : 1000 - x;
      canvas.drawLine(Offset(mirror(60), 372), Offset(mirror(96), 348), stripe);
      canvas.drawLine(Offset(mirror(112), 392), Offset(mirror(150), 358), stripe);
      canvas.drawLine(Offset(mirror(168), 404), Offset(mirror(204), 372), stripe);
    }

    // The cream patch the screen sits on.
    final patch = Path()
      ..addRRect(RRect.fromLTRBR(12, 346, 988, 798, const Radius.circular(150)));
    canvas.drawPath(patch, _fill(AppColors.furLight));
  }

  void _head(Canvas canvas, double phase, double blink) {
    final tilt = 0.05 * math.cos(2 * math.pi * phase);
    canvas.save();
    canvas.translate(500, 330);
    canvas.rotate(tilt);
    canvas.translate(-500, -330);

    for (final side in const [0.0, 1.0]) {
      double mirror(double x) => side == 0 ? x : 1000 - x;
      final ear = Path()
        ..moveTo(mirror(262), 172)
        ..lineTo(mirror(292), 30)
        ..lineTo(mirror(436), 104)
        ..close();
      _shape(canvas, ear, AppColors.fur);
      final inner = Path()
        ..moveTo(mirror(290), 152)
        ..lineTo(mirror(308), 70)
        ..lineTo(mirror(390), 114)
        ..close();
      canvas.drawPath(inner, _fill(AppColors.earInner));
    }

    final head = Path()..addOval(Rect.fromCenter(center: const Offset(500, 215), width: 524, height: 304));
    _shape(canvas, head, AppColors.fur);

    // Forehead stripes.
    final stripe = _line(AppColors.furDark, 16);
    canvas.drawLine(const Offset(500, 84), const Offset(500, 130), stripe);
    canvas.drawLine(const Offset(440, 90), const Offset(452, 128), stripe);
    canvas.drawLine(const Offset(560, 90), const Offset(548, 128), stripe);

    // Muzzle.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(500, 292), width: 208, height: 92),
      _fill(AppColors.furLight),
    );

    _eye(canvas, 398, 214, blink);
    _eye(canvas, 602, 214, blink);

    // Nose and mouth.
    final nose = Path()
      ..moveTo(474, 256)
      ..lineTo(526, 256)
      ..lineTo(500, 282)
      ..close();
    canvas.drawPath(nose, _fill(AppColors.nose));
    canvas.drawPath(nose, _line(AppColors.nose, 8));
    final mouth = _line(AppColors.outline, 6);
    canvas.drawLine(const Offset(500, 284), const Offset(500, 298), mouth);
    canvas.drawPath(
      Path()
        ..moveTo(500, 298)
        ..quadraticBezierTo(484, 316, 458, 304),
      mouth,
    );
    canvas.drawPath(
      Path()
        ..moveTo(500, 298)
        ..quadraticBezierTo(516, 316, 542, 304),
      mouth,
    );

    // Whiskers.
    final whisker = _line(AppColors.whisker, 4);
    for (final side in const [0.0, 1.0]) {
      double mirror(double x) => side == 0 ? x : 1000 - x;
      canvas.drawLine(Offset(mirror(414), 286), Offset(mirror(290), 262), whisker);
      canvas.drawLine(Offset(mirror(414), 298), Offset(mirror(276), 300), whisker);
      canvas.drawLine(Offset(mirror(414), 310), Offset(mirror(292), 338), whisker);
    }

    canvas.restore();
  }

  void _eye(Canvas canvas, double x, double y, double blink) {
    final open = 1 - 0.93 * blink;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: 60, height: 76 * open),
      _fill(AppColors.eye),
    );
    if (blink < 0.5) {
      canvas.drawCircle(Offset(x + 9, y - 13), 10, _fill(Colors.white));
      canvas.drawCircle(Offset(x - 8, y + 14), 5, _fill(Colors.white.withValues(alpha: 0.8)));
    }
  }

  @override
  bool shouldRepaint(CatPainter old) => old.pose != pose;
}
