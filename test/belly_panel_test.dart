import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/sample_weather.dart';
import 'package:cat_clock/display/belly_panel.dart';
import 'package:cat_clock/weather/weather_models.dart';
import 'package:cat_clock/weather/weather_rules.dart';

import 'helpers/pump.dart';

final localNow = DateTime(2026, 11, 12, 19, 42);

Widget panel({WeatherSnapshot? weather, WeatherFreshness freshness = WeatherFreshness.fresh}) {
  return Center(
    child: BellyPanel(
      hour24: 19,
      minute: 42,
      colonOn: true,
      weather: weather ?? sampleWeather(localNow),
      freshness: freshness,
      localNow: localNow,
    ),
  );
}

/// All texts under [root] that have a key starting with [prefix], in order of the number.
List<String> textsWithPrefix(WidgetTester tester, String prefix) {
  final found = <int, String>{};
  for (var i = 0; i < 6; i++) {
    final finder = find.byKey(Key('$prefix$i'));
    if (finder.evaluate().isNotEmpty) found[i] = tester.widget<Text>(finder).data!;
  }
  return [for (var i = 0; i < 6; i++) found[i] ?? ''];
}

void main() {
  const size = Size(1000, 460);

  group('layout', () {
    testWidgets('the weather starts to the right of the time', (tester) async {
      await pumpAtSize(tester, size, panel());
      final time = tester.getRect(find.byKey(const Key('time-block')));
      final weather = tester.getRect(find.byKey(const Key('weather-panel')));
      expect(weather.left, greaterThanOrEqualTo(time.right));
    });

    testWidgets('time and weather both sit inside the panel', (tester) async {
      await pumpAtSize(tester, size, panel());
      final belly = tester.getRect(find.byKey(const Key('belly-panel')));
      for (final key in ['time-block', 'weather-panel']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(belly.contains(rect.topLeft), isTrue, reason: '$key top left');
        expect(belly.contains(rect.bottomRight), isTrue, reason: '$key bottom right');
      }
    });

    testWidgets('the panel is 960 by 420 design units', (tester) async {
      await pumpAtSize(tester, size, panel());
      expect(tester.getSize(find.byKey(const Key('belly-panel'))), const Size(960, 420));
    });

    testWidgets('the six hour cells form two rows of three, left to right, none overlapping', (tester) async {
      await pumpAtSize(tester, size, panel());
      final rects = [
        for (var i = 0; i < 6; i++) tester.getRect(find.byKey(Key('hour-cell-$i'))),
      ];
      // Same row: same top, increasing left.
      expect(rects[0].top, rects[1].top);
      expect(rects[1].top, rects[2].top);
      expect(rects[3].top, rects[4].top);
      expect(rects[4].top, rects[5].top);
      expect(rects[3].top, greaterThan(rects[0].bottom - 0.001));
      expect(rects[1].left, greaterThan(rects[0].right - 0.001));
      expect(rects[2].left, greaterThan(rects[1].right - 0.001));
      expect(rects[4].left, greaterThan(rects[3].right - 0.001));
      expect(rects[5].left, greaterThan(rects[4].right - 0.001));
    });

    testWidgets('the Now cell is above the hour cells', (tester) async {
      await pumpAtSize(tester, size, panel());
      final now = tester.getRect(find.byKey(const Key('now-cell')));
      final firstRow = tester.getRect(find.byKey(const Key('hour-cell-0')));
      expect(now.bottom, lessThanOrEqualTo(firstRow.top));
    });

    testWidgets('every hour label fits inside its cell', (tester) async {
      await pumpAtSize(tester, size, panel());
      for (var i = 0; i < 6; i++) {
        final cell = tester.getRect(find.byKey(Key('hour-cell-$i')));
        for (final part in ['hour-label-', 'hour-icon-', 'hour-temp-']) {
          final rect = tester.getRect(find.byKey(Key('$part$i')));
          expect(rect.left, greaterThanOrEqualTo(cell.left - 0.01), reason: '$part$i left');
          expect(rect.right, lessThanOrEqualTo(cell.right + 0.01), reason: '$part$i right');
        }
      }
    });
  });

  group('what it shows', () {
    testWidgets('shows the six hours after now, with labels and temperatures', (tester) async {
      await pumpAtSize(tester, size, panel());
      expect(textsWithPrefix(tester, 'hour-label-'), ['8PM', '9PM', '10PM', '11PM', '12AM', '1AM']);
      expect(textsWithPrefix(tester, 'hour-temp-'), ['53°', '52°', '51°', '50°', '49°', '48°']);
      expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '54°');
    });

    double weatherOpacity(WidgetTester tester) {
      final opacity = find.ancestor(
        of: find.byKey(const Key('weather-panel')),
        matching: find.byType(Opacity),
      );
      return tester.widget<Opacity>(opacity.first).opacity;
    }

    testWidgets('fresh weather is drawn at full strength', (tester) async {
      await pumpAtSize(tester, size, panel());
      expect(weatherOpacity(tester), 1);
    });

    testWidgets('stale weather is dimmed', (tester) async {
      await pumpAtSize(tester, size, panel(freshness: WeatherFreshness.stale));
      expect(weatherOpacity(tester), 0.5);
    });

    testWidgets('unavailable weather shows dashes and still labels the hours', (tester) async {
      await pumpAtSize(
        tester,
        size,
        panel(freshness: WeatherFreshness.unavailable),
      );
      expect(textsWithPrefix(tester, 'hour-temp-'), List.filled(6, '--°'));
      expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '--°');
      // Labels come from the device clock: 7:42 PM now, so 8PM onward.
      expect(textsWithPrefix(tester, 'hour-label-'), ['8PM', '9PM', '10PM', '11PM', '12AM', '1AM']);
    });

    testWidgets('no weather at all is treated as unavailable', (tester) async {
      await pumpAtSize(
        tester,
        size,
        Center(
          child: BellyPanel(
            hour24: 7,
            minute: 5,
            colonOn: true,
            weather: null,
            freshness: WeatherFreshness.fresh,
            localNow: DateTime(2026, 11, 12, 7, 5),
          ),
        ),
      );
      expect(textsWithPrefix(tester, 'hour-temp-'), List.filled(6, '--°'));
      expect(textsWithPrefix(tester, 'hour-label-'), ['8AM', '9AM', '10AM', '11AM', '12PM', '1PM']);
    });

    testWidgets('a response with fewer than six hours fills the rest with dashes', (tester) async {
      final short = sampleWeather(localNow);
      final trimmed = WeatherSnapshot(
        fetchedAtUtc: short.fetchedAtUtc,
        latitude: short.latitude,
        longitude: short.longitude,
        unit: short.unit,
        now: short.now,
        nextHours: short.nextHours.sublist(0, 4),
      );
      await pumpAtSize(tester, size, panel(weather: trimmed));
      expect(textsWithPrefix(tester, 'hour-temp-'), ['53°', '52°', '51°', '50°', '--°', '--°']);
    });
  });

  group('saved image', () {
    testWidgets('fresh, stale, and unavailable panels', (tester) async {
      await pumpAtSize(
        tester,
        const Size(1000, 1340),
        Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                panel(),
                const SizedBox(height: 20),
                panel(freshness: WeatherFreshness.stale),
                const SizedBox(height: 20),
                panel(freshness: WeatherFreshness.unavailable),
              ],
            ),
          ),
        ),
      );
      await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/belly_states.png'));
    });
  });
}
