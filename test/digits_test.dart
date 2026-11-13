import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/theme.dart';
import 'package:cat_clock/display/seven_segment_painter.dart';
import 'package:cat_clock/display/time_display.dart';

import 'helpers/pump.dart';

void main() {
  group('colors', () {
    test('lit digits stand out from the panel by at least 4.5 to 1', () {
      final ratio = contrastRatio(AppColors.digitLit, AppColors.panel);
      expect(ratio, greaterThanOrEqualTo(4.5));
      // Recorded so a color change that weakens it is noticed in review.
      // ignore: avoid_print
      print('Contrast of lit digits on the panel: ${ratio.toStringAsFixed(2)} to 1');
    });

    test('lit digits also stand out from the page background', () {
      expect(contrastRatio(AppColors.digitLit, AppColors.background), greaterThanOrEqualTo(4.5));
    });

    test('weather text stands out from the panel', () {
      expect(contrastRatio(AppColors.labelText, AppColors.panel), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.valueText, AppColors.panel), greaterThanOrEqualTo(4.5));
    });

    test('contrastRatio gives the known values for black and white', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
    });
  });

  group('shapes', () {
    test('the seven bars of a digit do not overlap each other', () {
      final paths = segmentPaths(const Rect.fromLTWH(0, 0, 100, 200));
      final names = paths.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final overlap = Path.combine(PathOperation.intersect, paths[names[i]]!, paths[names[j]]!);
          expect(overlap.getBounds().isEmpty, isTrue, reason: '${names[i]} touches ${names[j]}');
        }
      }
    });

    test('every bar stays inside the digit box', () {
      const box = Rect.fromLTWH(10, 20, 100, 200);
      for (final entry in segmentPaths(box).entries) {
        final bounds = entry.value.getBounds();
        expect(box.inflate(0.01).contains(bounds.topLeft), isTrue, reason: entry.key);
        expect(box.inflate(0.01).contains(bounds.bottomRight), isTrue, reason: entry.key);
      }
    });

    test('the time digits are 2.4 times as wide as they are tall', () {
      expect(timeDigitsAspect, closeTo(2.4, 1e-9));
    });
  });

  group('saved images', () {
    testWidgets('digits 0 to 9 and a blank cell', (tester) async {
      await pumpAtSize(
        tester,
        const Size(1000, 200),
        Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: Container(
              color: AppColors.panel,
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final digit in <int?>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, null])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: 70,
                        height: 140,
                        child: CustomPaint(painter: SevenSegmentDigitPainter(digit)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/digits.png'));
    });

    testWidgets('three times with the colon on and off', (tester) async {
      await pumpAtSize(
        tester,
        const Size(700, 760),
        Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: Container(
              color: AppColors.panel,
              padding: const EdgeInsets.all(24),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TimeDisplay(hour24: 19, minute: 42),
                  SizedBox(height: 24),
                  TimeDisplay(hour24: 0, minute: 5, colonOn: false),
                  SizedBox(height: 24),
                  TimeDisplay(hour24: 12, minute: 59),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/time_display.png'));
    });
  });
}
