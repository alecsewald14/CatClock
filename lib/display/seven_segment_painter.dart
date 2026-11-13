import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../clock/time_format.dart';

/// Shape rules for the clock digits, all relative to a digit's height.
const double digitWidthRatio = 0.5;
const double digitGapRatio = 0.05;
const double colonWidthRatio = 0.2;

/// Width of "H:MM" (four digits, a colon, four gaps) divided by its height.
const double timeDigitsAspect =
    4 * digitWidthRatio + colonWidthRatio + 4 * digitGapRatio;

/// Which of the seven segments (a top, b top right, c bottom right, d bottom,
/// e bottom left, f top left, g middle) are lit for each digit.
const Map<int, String> _litSegments = <int, String>{
  0: 'abcdef',
  1: 'bc',
  2: 'abdeg',
  3: 'abcdg',
  4: 'bcfg',
  5: 'acdfg',
  6: 'acdefg',
  7: 'abc',
  8: 'abcdefg',
  9: 'abcdfg',
};

Path _horizontalBar(double x1, double x2, double y, double thickness) {
  final half = thickness / 2;
  return Path()
    ..moveTo(x1, y)
    ..lineTo(x1 + half, y - half)
    ..lineTo(x2 - half, y - half)
    ..lineTo(x2, y)
    ..lineTo(x2 - half, y + half)
    ..lineTo(x1 + half, y + half)
    ..close();
}

Path _verticalBar(double x, double y1, double y2, double thickness) {
  final half = thickness / 2;
  return Path()
    ..moveTo(x, y1)
    ..lineTo(x + half, y1 + half)
    ..lineTo(x + half, y2 - half)
    ..lineTo(x, y2)
    ..lineTo(x - half, y2 - half)
    ..lineTo(x - half, y1 + half)
    ..close();
}

/// The seven bar shapes for a digit drawn inside [rect], keyed 'a' to 'g'.
Map<String, Path> segmentPaths(Rect rect) {
  final thickness = rect.width * 0.2;
  final gap = thickness * 0.45;
  final left = rect.left + thickness / 2;
  final right = rect.right - thickness / 2;
  final top = rect.top + thickness / 2;
  final bottom = rect.bottom - thickness / 2;
  final middle = rect.center.dy;
  return <String, Path>{
    'a': _horizontalBar(left + gap, right - gap, top, thickness),
    'g': _horizontalBar(left + gap, right - gap, middle, thickness),
    'd': _horizontalBar(left + gap, right - gap, bottom, thickness),
    'f': _verticalBar(left, top + gap, middle - gap, thickness),
    'b': _verticalBar(right, top + gap, middle - gap, thickness),
    'e': _verticalBar(left, middle + gap, bottom - gap, thickness),
    'c': _verticalBar(right, middle + gap, bottom - gap, thickness),
  };
}

void _paintLit(Canvas canvas, Path path, Color color, double glowSigma) {
  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
  );
  canvas.drawPath(path, Paint()..color = color);
}

void _paintUnlit(Canvas canvas, Path path, Color color, double opacity) {
  canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
}

/// Draws one digit. A null [digit] draws a blank cell: every segment unlit.
void paintSevenSegmentDigit(
  Canvas canvas,
  Rect rect,
  int? digit, {
  Color lit = AppColors.digitLit,
  double unlitOpacity = AppColors.digitUnlitOpacity,
}) {
  final onSegments = digit == null ? '' : (_litSegments[digit] ?? '');
  final glowSigma = rect.width * 0.12;
  final paths = segmentPaths(rect);
  // Unlit segments first, so a glow never hides them.
  for (final entry in paths.entries) {
    if (!onSegments.contains(entry.key)) {
      _paintUnlit(canvas, entry.value, lit, unlitOpacity);
    }
  }
  for (final entry in paths.entries) {
    if (onSegments.contains(entry.key)) {
      _paintLit(canvas, entry.value, lit, glowSigma);
    }
  }
}

/// Draws the two dots of the colon inside [rect]. When [on] is false they show unlit.
void paintColon(
  Canvas canvas,
  Rect rect,
  bool on, {
  Color lit = AppColors.digitLit,
  double unlitOpacity = AppColors.digitUnlitOpacity,
}) {
  final side = rect.height * 0.1;
  for (final fraction in const [0.32, 0.68]) {
    final dot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + rect.height * fraction),
        width: side,
        height: side,
      ),
      Radius.circular(side * 0.15),
    );
    final path = Path()..addRRect(dot);
    if (on) {
      _paintLit(canvas, path, lit, side * 0.6);
    } else {
      _paintUnlit(canvas, path, lit, unlitOpacity);
    }
  }
}

/// Paints one seven-segment digit, filling its box.
class SevenSegmentDigitPainter extends CustomPainter {
  const SevenSegmentDigitPainter(this.digit, {this.lit = AppColors.digitLit});

  final int? digit;
  final Color lit;

  @override
  void paint(Canvas canvas, Size size) {
    paintSevenSegmentDigit(canvas, Offset.zero & size, digit, lit: lit);
  }

  @override
  bool shouldRepaint(SevenSegmentDigitPainter old) => old.digit != digit || old.lit != lit;
}

/// Paints the time digits "H:MM" in 12-hour form, centered in the box.
///
/// The hour has no leading zero: at 7:42 the first digit is blank (shown unlit).
class TimeDigitsPainter extends CustomPainter {
  const TimeDigitsPainter({
    required this.hour24,
    required this.minute,
    required this.colonOn,
    this.lit = AppColors.digitLit,
  });

  final int hour24;
  final int minute;
  final bool colonOn;
  final Color lit;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final digitWidth = height * digitWidthRatio;
    final gap = height * digitGapRatio;
    final colonWidth = height * colonWidthRatio;
    var x = (size.width - height * timeDigitsAspect) / 2;

    final hour12 = to12Hour(hour24).hour12;
    final digits = <int?>[hour12 >= 10 ? hour12 ~/ 10 : null, hour12 % 10, minute ~/ 10, minute % 10];

    void digitAt(int? digit) {
      paintSevenSegmentDigit(canvas, Rect.fromLTWH(x, 0, digitWidth, height), digit, lit: lit);
      x += digitWidth + gap;
    }

    digitAt(digits[0]);
    digitAt(digits[1]);
    paintColon(canvas, Rect.fromLTWH(x, 0, colonWidth, height), colonOn, lit: lit);
    x += colonWidth + gap;
    digitAt(digits[2]);
    digitAt(digits[3]);
  }

  @override
  bool shouldRepaint(TimeDigitsPainter old) {
    return old.hour24 != hour24 ||
        old.minute != minute ||
        old.colonOn != colonOn ||
        old.lit != lit;
  }
}
