import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'weather_codes.dart';

/// Draws one of the 12 weather pictures, filling the shorter side of its box.
class WeatherIconPainter extends CustomPainter {
  const WeatherIconPainter(this.icon);

  final WeatherIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    _draw(canvas, icon);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WeatherIconPainter old) => old.icon != icon;
}

// ---- Drawing, in a 100 by 100 box ----

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

/// A cloud about 76 wide, scaled around the middle of the box and then moved by (dx, dy).
Path _cloud({double dx = 0, double dy = 0, double scale = 1}) {
  var cloud = _circle(32, 54, 17);
  cloud = Path.combine(PathOperation.union, cloud, _circle(52, 44, 21));
  cloud = Path.combine(PathOperation.union, cloud, _circle(72, 54, 15));
  cloud = Path.combine(
    PathOperation.union,
    cloud,
    Path()..addRRect(RRect.fromLTRBR(15, 52, 87, 71, const Radius.circular(9.5))),
  );
  final matrix = Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..translateByDouble(50, 50, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-50, -50, 0, 1);
  return cloud.transform(matrix.storage);
}

void _fill(Canvas canvas, Path path, Color color) {
  canvas.drawPath(path, Paint()..color = color);
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _sun(Canvas canvas, double x, double y, double r, {required double rayStart, required double rayEnd, required double rayWidth}) {
  canvas.drawCircle(Offset(x, y), r, Paint()..color = AppColors.sun);
  final paint = _stroke(AppColors.sun, rayWidth);
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    canvas.drawLine(
      Offset(x + math.cos(angle) * rayStart, y + math.sin(angle) * rayStart),
      Offset(x + math.cos(angle) * rayEnd, y + math.sin(angle) * rayEnd),
      paint,
    );
  }
}

Path _moon(double x, double y, double r) {
  return Path.combine(
    PathOperation.difference,
    _circle(x, y, r),
    _circle(x + r * 0.5, y - r * 0.32, r * 0.84),
  );
}

void _drops(Canvas canvas, List<List<double>> lines, Color color, double width) {
  final paint = _stroke(color, width);
  for (final line in lines) {
    canvas.drawLine(Offset(line[0], line[1]), Offset(line[2], line[3]), paint);
  }
}

void _dots(Canvas canvas, List<List<double>> dots, Color color) {
  for (final dot in dots) {
    canvas.drawCircle(Offset(dot[0], dot[1]), dot[2], Paint()..color = color);
  }
}

void _draw(Canvas canvas, WeatherIcon icon) {
  switch (icon) {
    case WeatherIcon.clearDay:
      _sun(canvas, 50, 50, 17, rayStart: 26, rayEnd: 38, rayWidth: 6);
    case WeatherIcon.clearNight:
      _fill(canvas, _moon(50, 52, 29), AppColors.moon);
    case WeatherIcon.partlyDay:
      _sun(canvas, 38, 38, 13, rayStart: 20, rayEnd: 29, rayWidth: 5);
      _fill(canvas, _cloud(dx: 6, dy: 14, scale: 0.9), AppColors.cloudLight);
    case WeatherIcon.partlyNight:
      _fill(canvas, _moon(38, 38, 20), AppColors.moon);
      _fill(canvas, _cloud(dx: 6, dy: 14, scale: 0.9), AppColors.cloudLight);
    case WeatherIcon.cloudy:
      _fill(canvas, _cloud(dx: -9, dy: -12, scale: 0.78), AppColors.cloudDark);
      _fill(canvas, _cloud(dx: 4, dy: 6, scale: 0.96), AppColors.cloudLight);
    case WeatherIcon.fog:
      _fill(canvas, _cloud(dx: 0, dy: -14, scale: 0.9), AppColors.cloudLight);
      _drops(
        canvas,
        const [
          [18, 70, 82, 70],
          [28, 81, 92, 81],
          [14, 92, 74, 92],
        ],
        AppColors.fog,
        6,
      );
    case WeatherIcon.drizzle:
      _fill(canvas, _cloud(dy: -12, scale: 0.92), AppColors.cloudLight);
      _drops(
        canvas,
        const [
          [36, 70, 33, 78],
          [52, 74, 49, 82],
          [68, 70, 65, 78],
        ],
        AppColors.rain.withValues(alpha: 0.85),
        4.5,
      );
    case WeatherIcon.rain:
      _fill(canvas, _cloud(dy: -12, scale: 0.92), AppColors.cloudDark);
      _drops(
        canvas,
        const [
          [30, 68, 24, 86],
          [46, 68, 40, 86],
          [62, 68, 56, 86],
          [78, 68, 72, 86],
        ],
        AppColors.rain,
        5,
      );
    case WeatherIcon.sleet:
      _fill(canvas, _cloud(dy: -12, scale: 0.92), AppColors.cloudDark);
      _drops(
        canvas,
        const [
          [30, 68, 24, 84],
          [62, 68, 56, 84],
        ],
        AppColors.rain,
        5,
      );
      _dots(
        canvas,
        const [
          [46, 76, 4.5],
          [78, 76, 4.5],
          [38, 91, 4.5],
          [70, 91, 4.5],
        ],
        AppColors.snow,
      );
    case WeatherIcon.snow:
      _fill(canvas, _cloud(dy: -12, scale: 0.92), AppColors.cloudLight);
      _dots(
        canvas,
        const [
          [28, 72, 5],
          [50, 80, 5],
          [72, 72, 5],
          [38, 93, 5],
          [62, 93, 5],
        ],
        AppColors.snow,
      );
    case WeatherIcon.thunder:
      _fill(canvas, _cloud(dy: -12, scale: 0.92), AppColors.cloudDark);
      final bolt = Path()
        ..moveTo(56, 56)
        ..lineTo(36, 82)
        ..lineTo(49, 82)
        ..lineTo(42, 100)
        ..lineTo(68, 70)
        ..lineTo(54, 70)
        ..lineTo(63, 56)
        ..close();
      _fill(canvas, bolt, AppColors.bolt);
    case WeatherIcon.unavailable:
      canvas.drawPath(_cloud(dy: -4, scale: 0.95), _stroke(AppColors.unavailable, 5));
      canvas.drawLine(const Offset(22, 88), const Offset(78, 14), _stroke(AppColors.unavailable, 5));
  }
}
