import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/theme.dart';
import 'package:cat_clock/weather/weather_codes.dart';
import 'package:cat_clock/weather/weather_icons.dart';

import 'helpers/pump.dart';

void main() {
  testWidgets('every one of the 12 icons draws something', (tester) async {
    await tester.runAsync(() async {
      for (final icon in WeatherIcon.values) {
        final recorder = ui.PictureRecorder();
        WeatherIconPainter(icon).paint(ui.Canvas(recorder), const Size(100, 100));
        final image = await recorder.endRecording().toImage(100, 100);
        final bytes = (await image.toByteData())!;
        var painted = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 0) painted++;
        }
        expect(painted, greaterThan(400), reason: '$icon looks empty');
        expect(painted, lessThan(9000), reason: '$icon fills the whole box');
      }
    });
  });

  testWidgets('different icons look different from each other', (tester) async {
    await tester.runAsync(() async {
      final fingerprints = <String, WeatherIcon>{};
      for (final icon in WeatherIcon.values) {
        final recorder = ui.PictureRecorder();
        WeatherIconPainter(icon).paint(ui.Canvas(recorder), const Size(60, 60));
        final image = await recorder.endRecording().toImage(60, 60);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        final key = bytes.join(',').hashCode.toString();
        expect(fingerprints.containsKey(key), isFalse,
            reason: '$icon is identical to ${fingerprints[key]}');
        fingerprints[key] = icon;
      }
    });
  });

  testWidgets('saved image of all 12 icons', (tester) async {
    await pumpAtSize(
      tester,
      const Size(760, 620),
      Center(
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            color: AppColors.panel,
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in WeatherIcon.values)
                  SizedBox(
                    width: 160,
                    height: 180,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(painter: WeatherIconPainter(icon)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          icon.name,
                          style: const TextStyle(fontSize: 16, color: AppColors.labelText),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/weather_icons.png'));
  });
}
