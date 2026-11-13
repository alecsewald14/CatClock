import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_controller.dart';
import 'package:cat_clock/app/alarm_bar.dart';
import 'package:cat_clock/app/cat_clock_screen.dart';
import 'package:cat_clock/app/sample_weather.dart';
import 'package:cat_clock/platform/signature_info.dart';
import 'package:cat_clock/weather/weather_models.dart';
import 'package:cat_clock/weather/weather_rules.dart';

import 'helpers/pump.dart';

final now = DateTime(2026, 11, 12, 19, 42);

const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const laptop = Size(1280, 800);

CatClockScreen screen({
  WeatherSnapshot? weather,
  WeatherFreshness freshness = WeatherFreshness.fresh,
  Alarm alarm = const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
  AlarmState state = AlarmState.armed,
  DateTime? snoozeUntil,
  DateTime? missedAt,
  bool soundProblem = false,
  VoidCallback? onAlarmTap,
  VoidCallback? onStop,
  VoidCallback? onSnooze,
  VoidCallback? onDismissMissed,
  VoidCallback? onAttributionTap,
  bool showAttribution = true,
  String? note,
  SignatureMessage? signature,
}) {
  return CatClockScreen(
    now: now,
    colonOn: true,
    weather: weather ?? sampleWeather(now),
    freshness: freshness,
    alarm: alarm,
    alarmState: state,
    snoozeUntil: snoozeUntil,
    missedAt: missedAt,
    soundProblem: soundProblem,
    animateCat: false,
    showAttribution: showAttribution,
    footerNote: note,
    signature: signature,
    onAlarmTap: onAlarmTap,
    onStop: onStop,
    onSnooze: onSnooze,
    onDismissMissed: onDismissMissed,
    onAttributionTap: onAttributionTap,
  );
}

Rect rectOf(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

void main() {
  const sizes = <String, Size>{
    'phone portrait': phonePortrait,
    'phone landscape': phoneLandscape,
    'laptop': laptop,
  };

  group('layout at every size', () {
    sizes.forEach((name, size) {
      testWidgets('$name: the weather is to the right of the time', (tester) async {
        await pumpAtSize(tester, size, screen());
        expect(
          rectOf(tester, 'weather-panel').left,
          greaterThanOrEqualTo(rectOf(tester, 'time-block').right),
        );
      });

      testWidgets('$name: everything fits on the screen without overlapping', (tester) async {
        await pumpAtSize(tester, size, screen());
        final window = Offset.zero & size;
        for (final key in ['belly-panel', 'cat-scene', 'alarm-bar', 'footer']) {
          final rect = rectOf(tester, key);
          expect(window.contains(rect.topLeft), isTrue, reason: '$key top left $rect');
          expect(window.inflate(0.5).contains(rect.bottomRight), isTrue, reason: '$key bottom right $rect');
        }
        expect(rectOf(tester, 'cat-scene').bottom, lessThanOrEqualTo(rectOf(tester, 'alarm-bar').top + 0.5));
        expect(rectOf(tester, 'alarm-bar').bottom, lessThanOrEqualTo(rectOf(tester, 'footer').top + 0.5));
      });

      testWidgets('$name: the time, AM/PM, and weather are all on the belly', (tester) async {
        await pumpAtSize(tester, size, screen());
        final belly = rectOf(tester, 'belly-panel');
        for (final key in ['digits', 'am-pm', 'weather-panel']) {
          final rect = rectOf(tester, key);
          expect(belly.inflate(0.5).contains(rect.topLeft), isTrue, reason: key);
          expect(belly.inflate(0.5).contains(rect.bottomRight), isTrue, reason: key);
        }
        expect(rectOf(tester, 'am-pm').left, greaterThanOrEqualTo(rectOf(tester, 'digits').right));
      });
    });
  });

  group('sizes on a 390-point-wide phone in portrait', () {
    testWidgets('the time digits are at least 70 points tall', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      final height = rectOf(tester, 'digits').height;
      expect(height, greaterThanOrEqualTo(70));
      // ignore: avoid_print
      print('Digit height on a 390-wide phone: ${height.toStringAsFixed(1)} points');
    });

    testWidgets('the weather pictures are at least 20 points tall', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      expect(rectOf(tester, 'now-icon').height, greaterThanOrEqualTo(20));
      for (var i = 0; i < 6; i++) {
        expect(rectOf(tester, 'hour-icon-$i').height, greaterThanOrEqualTo(20), reason: 'hour $i');
      }
    });

    testWidgets('hour labels and temperatures are at least 11 points tall', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      final smallest = <double>[
        for (var i = 0; i < 6; i++) rectOf(tester, 'hour-label-$i').height,
        for (var i = 0; i < 6; i++) rectOf(tester, 'hour-temp-$i').height,
        rectOf(tester, 'now-temp').height,
      ].reduce((a, b) => a < b ? a : b);
      expect(smallest, greaterThanOrEqualTo(11));
      // ignore: avoid_print
      print('Smallest weather text on a 390-wide phone: ${smallest.toStringAsFixed(1)} points');
    });

    testWidgets('the belly panel is nearly as wide as the screen', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      expect(rectOf(tester, 'belly-panel').width, greaterThan(340));
    });
  });

  group('large text settings', () {
    testWidgets('do not change the size of the weather text, which sits in fixed cells', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      final normal = rectOf(tester, 'hour-label-0');
      await pumpAtSize(tester, phonePortrait, screen(), textScale: 2);
      expect(rectOf(tester, 'hour-label-0').size, normal.size);
    });

    testWidgets('the alarm strip and footer still fit at double text size', (tester) async {
      await pumpAtSize(
        tester,
        phonePortrait,
        screen(note: 'Sample weather, not live yet'),
        textScale: 2,
      );
      final window = Offset.zero & phonePortrait;
      for (final key in ['alarm-bar', 'footer']) {
        final rect = rectOf(tester, key);
        expect(window.inflate(0.5).contains(rect.topLeft), isTrue, reason: key);
        expect(window.inflate(0.5).contains(rect.bottomRight), isTrue, reason: key);
      }
    });
  });

  group('the iPhone signature line', () {
    const calm = SignatureMessage('Signature: 6 days left', warning: false);
    const warning = SignatureMessage('Signature: 1 day left. Renew it with AltStore soon.', warning: true);

    testWidgets('is not shown where there is no signature, as on Windows', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      expect(find.byKey(const Key('signature')), findsNothing);
    });

    testWidgets('shows the days left in the footer, in the quiet small-print style', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(signature: calm));
      final text = tester.widget<Text>(find.byKey(const Key('signature')));
      expect(text.data, 'Signature: 6 days left');
      expect(text.style!.fontWeight, FontWeight.w400);
      expect(find.descendant(of: find.byKey(const Key('footer')), matching: find.byKey(const Key('signature'))), findsOneWidget);
    });

    testWidgets('a warning is bold and in a warm red, so it stands out from the small print', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(signature: warning));
      final style = tester.widget<Text>(find.byKey(const Key('signature'))).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, const Color(0xFFFF8A80));
    });

    sizes.forEach((name, size) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name, text x$scale: the footer with everything in it still fits on the screen', (tester) async {
          await pumpAtSize(
            tester,
            size,
            screen(
              freshness: WeatherFreshness.stale,
              note: 'Alarms are turned off for Cat Clock. Turn them on in the iPhone\'s Settings.',
              signature: warning,
            ),
            textScale: scale,
          );
          final window = Offset.zero & size;
          for (final key in ['alarm-bar', 'footer', 'signature']) {
            final rect = rectOf(tester, key);
            expect(window.inflate(0.5).contains(rect.topLeft), isTrue, reason: '$key top left $rect');
            expect(window.inflate(0.5).contains(rect.bottomRight), isTrue, reason: '$key bottom right $rect');
          }
          expect(rectOf(tester, 'alarm-bar').bottom, lessThanOrEqualTo(rectOf(tester, 'footer').top + 0.5));
          expect(tester.takeException(), isNull);
        });
      }
    });
  });

  group('alarm strip', () {
    testWidgets('shows the alarm time, sound, volume, and repeat', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      expect(find.text('Alarm  6:30 AM'), findsOneWidget);
      expect(find.text('ON'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('alarm-details'))).data,
        'Soft Chime  ·  Volume 3 of 5  ·  Every day',
      );
    });

    testWidgets('shows OFF when the alarm is off', (tester) async {
      await pumpAtSize(
        tester,
        phonePortrait,
        screen(alarm: const Alarm(hour: 7, minute: 15)),
      );
      expect(find.text('Alarm  7:15 AM'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('says when a snoozed alarm will ring again, and offers Stop', (tester) async {
      var stops = 0;
      await pumpAtSize(
        tester,
        phonePortrait,
        screen(
          state: AlarmState.snoozed,
          snoozeUntil: DateTime(2026, 11, 12, 6, 39),
          onStop: () => stops++,
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('alarm-details'))).data,
        startsWith('Snoozed until 6:39 AM  ·  '),
      );
      expect(find.text('ON'), findsNothing, reason: 'Stop takes the place of the pill');
      await tester.tap(find.byKey(const Key('bar-stop')));
      expect(stops, 1);
    });

    testWidgets('says when a missed alarm was due, and offers Dismiss', (tester) async {
      var dismissed = 0;
      await pumpAtSize(
        tester,
        phonePortrait,
        screen(
          state: AlarmState.missed,
          missedAt: DateTime(2026, 11, 12, 6, 30),
          onDismissMissed: () => dismissed++,
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('alarm-details'))).data,
        startsWith('Missed 6:30 AM  ·  '),
      );
      await tester.tap(find.byKey(const Key('bar-dismiss')));
      expect(dismissed, 1);
    });

    testWidgets('a snoozed or missed alarm without handlers shows the pill instead', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(state: AlarmState.snoozed));
      expect(find.byKey(const Key('bar-stop')), findsNothing);
      expect(find.text('ON'), findsOneWidget);
    });

    testWidgets('while ringing, the Stop and Snooze buttons replace the strip', (tester) async {
      var stops = 0;
      var snoozes = 0;
      await pumpAtSize(
        tester,
        phonePortrait,
        screen(state: AlarmState.ringing, onStop: () => stops++, onSnooze: () => snoozes++),
      );
      expect(find.byKey(const Key('alarm-bar')), findsNothing);
      expect(find.byKey(const Key('ringing-panel')), findsOneWidget);
      expect(find.text('Alarm  6:30 AM'), findsOneWidget);
      expect(find.text('Snooze 9 min'), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop-button')));
      await tester.tap(find.byKey(const Key('snooze-button')));
      expect((stops, snoozes), (1, 1));
    });

    testWidgets('the ringing buttons are big enough to hit half asleep', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(state: AlarmState.ringing));
      expect(rectOf(tester, 'stop-button').height, greaterThanOrEqualTo(56));
      expect(rectOf(tester, 'snooze-button').height, greaterThanOrEqualTo(56));
      expect(rectOf(tester, 'stop-button').width, greaterThanOrEqualTo(120));
    });

    testWidgets('the ringing panel fits on every size, even with large text', (tester) async {
      for (final entry in sizes.entries) {
        await pumpAtSize(tester, entry.value, screen(state: AlarmState.ringing, soundProblem: true), textScale: 2);
        final window = Offset.zero & entry.value;
        final rect = rectOf(tester, 'ringing-panel');
        expect(window.inflate(0.5).contains(rect.topLeft), isTrue, reason: '${entry.key} top left');
        expect(window.inflate(0.5).contains(rect.bottomRight), isTrue, reason: '${entry.key} bottom right');
      }
    });

    testWidgets('shows why the alarm is silent when the sound cannot play', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(state: AlarmState.ringing, soundProblem: true));
      expect(find.text('The alarm sound could not be played.'), findsOneWidget);
    });

    testWidgets('does not mention the sound problem otherwise', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(state: AlarmState.ringing));
      expect(find.byKey(const Key('sound-problem')), findsNothing);
    });

    testWidgets('tapping it opens the alarm settings', (tester) async {
      var taps = 0;
      await pumpAtSize(tester, phonePortrait, screen(onAlarmTap: () => taps++));
      await tester.tap(find.byKey(const Key('alarm-bar')));
      expect(taps, 1);
    });

    test('sound ids become readable names', () {
      expect(soundDisplayName('soft_chime'), 'Soft Chime');
      expect(soundDisplayName('cat_bell'), 'Cat Bell');
      expect(soundDisplayName('classic_beep'), 'Classic Beep');
      expect(soundDisplayName('purr'), 'Purr');
      expect(soundDisplayName(''), '');
    });
  });

  group('footer', () {
    testWidgets('shows the Open-Meteo credit, and tapping it calls the handler', (tester) async {
      var taps = 0;
      await pumpAtSize(tester, phonePortrait, screen(onAttributionTap: () => taps++));
      expect(find.text('Weather data by Open-Meteo.com'), findsOneWidget);
      await tester.tap(find.byKey(const Key('attribution')));
      expect(taps, 1);
    });

    testWidgets('hides the credit when the weather is made up', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(showAttribution: false, note: 'Sample weather'));
      expect(find.text('Weather data by Open-Meteo.com'), findsNothing);
      expect(find.text('Sample weather'), findsOneWidget);
    });

    testWidgets('shows when stale weather was last updated', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(freshness: WeatherFreshness.stale));
      final text = tester.widget<Text>(find.byKey(const Key('updated'))).data!;
      expect(text, matches(RegExp(r'^updated \d{1,2}:\d{2} (AM|PM)$')));
    });

    testWidgets('shows no "updated" text for fresh weather', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen());
      expect(find.byKey(const Key('updated')), findsNothing);
    });
  });

  group('saved images', () {
    testWidgets('phone in portrait', (tester) async {
      await pumpAtSize(tester, phonePortrait, screen(note: null), pixelRatio: 2);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screen_phone_portrait.png'));
    });

    testWidgets('phone in landscape', (tester) async {
      await pumpAtSize(tester, phoneLandscape, screen(), pixelRatio: 2);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screen_phone_landscape.png'));
    });

    testWidgets('laptop window', (tester) async {
      await pumpAtSize(tester, laptop, screen());
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screen_laptop.png'));
    });
  });
}
