import 'package:flutter/material.dart';

import '../clock/time_format.dart';
import 'ampm_painter.dart';
import 'seven_segment_painter.dart';

/// The time on the cat's belly: blue digits, then the AM/PM letters to their right.
class TimeDisplay extends StatelessWidget {
  const TimeDisplay({
    super.key,
    required this.hour24,
    required this.minute,
    this.colonOn = true,
  });

  final int hour24;
  final int minute;

  /// The colon blinks once a second; the screen flips this.
  final bool colonOn;

  /// Height of the digits, in design units. See the spec: at least 70 points tall on a
  /// 390-point-wide iPhone in portrait.
  static const double digitsHeight = 196;
  static const double digitsWidth = digitsHeight * timeDigitsAspect;
  static const double gap = 16;
  static const double amPmWidth = 64;
  static const double width = digitsWidth + gap + amPmWidth;

  @override
  Widget build(BuildContext context) {
    final isPm = to12Hour(hour24).isPm;
    final spoken = '${formatClockDigits(hour24, minute)} ${isPm ? 'PM' : 'AM'}';
    return Semantics(
      label: 'Time $spoken',
      excludeSemantics: true,
      child: SizedBox(
        key: const Key('time-block'),
        width: width,
        height: digitsHeight,
        child: Row(
          children: [
            SizedBox(
              key: const Key('digits'),
              width: digitsWidth,
              height: digitsHeight,
              child: CustomPaint(
                painter: TimeDigitsPainter(hour24: hour24, minute: minute, colonOn: colonOn),
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              key: const Key('am-pm'),
              width: amPmWidth,
              height: digitsHeight,
              child: CustomPaint(painter: AmPmPainter(isPm: isPm)),
            ),
          ],
        ),
      ),
    );
  }
}
