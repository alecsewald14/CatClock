import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/main.dart';
import 'package:cat_clock/storage/text_storage.dart';
import 'package:cat_clock/weather/location_service.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_cache.dart';
import 'package:cat_clock/weather/weather_problem.dart';
import 'package:cat_clock/weather/weather_repository.dart';
import 'package:cat_clock/weather/weather_rules.dart';

import 'helpers/pump.dart';
import 'helpers/weather_fakes.dart';

/// 12:34 PM local time, a Thursday.
final fixedNow = DateTime(2026, 11, 12, 12, 34, 5);
final utcNow = DateTime.utc(2026, 11, 12, 17, 34, 5);

class Rig {
  Rig({List<LocationResult>? location, List<Object>? outcomes, TextStorage? storage})
      : clock = FakeClock(utcNow),
        scheduler = FakeScheduler() {
    this.location = FakeLocation(location ?? [const LocationFound(40.7128, -74.0060)]);
    fetcher = FakeFetcher(outcomes ?? [snapshotAt(utcNow)]);
    repo = WeatherRepository(
      location: this.location,
      fetcher: fetcher,
      cache: WeatherCache(storage ?? MemoryTextStorage()),
      nowUtc: clock.call,
      unit: () => TemperatureUnit.fahrenheit,
      scheduler: scheduler,
    );
  }

  final FakeClock clock;
  final FakeScheduler scheduler;
  late final FakeLocation location;
  late final FakeFetcher fetcher;
  late final WeatherRepository repo;
  final List<Uri> opened = [];

  Widget app() => CatClockApp(
        weather: repo,
        openLink: (uri) async => opened.add(uri),
        clock: () => fixedNow,
      );
}

Future<void> showApp(WidgetTester tester, Rig rig) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(rig.app());
  await tester.pump(); // let the first refresh finish
  await tester.pump();
}

Future<void> leave(WidgetTester tester) async {
  // Leave the screen so the one-second timer and the cat's timer are cancelled.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('the app opens on the cat clock screen with the real time', (tester) async {
    final rig = Rig();
    await showApp(tester, rig);
    expect(find.byKey(const Key('belly-panel')), findsOneWidget);
    expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
    expect(find.byKey(const Key('cat')), findsOneWidget);
    expect(find.bySemanticsLabel('Time 12:34 PM'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('shows the weather that was fetched', (tester) async {
    final rig = Rig(outcomes: [snapshotAt(utcNow, temperature: 61)]);
    await showApp(tester, rig);
    expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '61°');
    expect(tester.widget<Text>(find.byKey(const Key('hour-temp-0'))).data, '60°');
    expect(tester.widget<Text>(find.byKey(const Key('hour-label-0'))).data, '1PM');
    expect(rig.fetcher.requests.length, 1);
    await leave(tester);
  });

  testWidgets('shows the Open-Meteo credit, and tapping it opens their home page', (tester) async {
    final rig = Rig();
    await showApp(tester, rig);
    expect(find.text('Weather data by Open-Meteo.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attribution')));
    expect(rig.opened, [Uri.parse('https://open-meteo.com/')]);
    await leave(tester);
  });

  testWidgets('tells the person plainly when location is turned off, and the clock still works', (tester) async {
    final rig = Rig(location: [const LocationFailed(WeatherProblem.locationDisabled)]);
    await showApp(tester, rig);
    expect(
      tester.widget<Text>(find.byKey(const Key('note'))).data,
      contains('location is turned off'),
    );
    expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '--°');
    expect(find.bySemanticsLabel('Time 12:34 PM'), findsOneWidget);
    expect(find.byKey(const Key('attribution')), findsNothing, reason: 'no weather data is shown');
    await leave(tester);
  });

  testWidgets('keeps showing old weather, dimmed, with its time, when the weather goes stale', (tester) async {
    final rig = Rig();
    await showApp(tester, rig);
    expect(rig.repo.freshness(), WeatherFreshness.fresh);

    rig.clock.now = utcNow.add(const Duration(minutes: 31));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('updated')), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.descendant(
        of: find.byKey(const Key('belly-panel')),
        matching: find.byType(Opacity),
      ).first).opacity,
      0.5,
    );
    await leave(tester);
  });

  testWidgets('stops refreshing when the app is hidden, and refreshes when it comes back', (tester) async {
    final rig = Rig();
    await showApp(tester, rig);
    expect(rig.scheduler.pending, isNotNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(rig.scheduler.pending, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(rig.fetcher.requests.length, 2);
    expect(rig.scheduler.pending, isNotNull);
    await leave(tester);
  });

  testWidgets('losing focus alone does not stop the weather', (tester) async {
    final rig = Rig();
    await showApp(tester, rig);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(rig.scheduler.pending, isNotNull);
    await leave(tester);
  });

  testWidgets('shows weather already saved on the device before the new weather arrives', (tester) async {
    final storage = MemoryTextStorage();
    await WeatherCache(storage).save(snapshotAt(utcNow.subtract(const Duration(minutes: 5)), temperature: 33));
    final rig = Rig(storage: storage, location: [const LocationFailed(WeatherProblem.locationDisabled)]);
    await showApp(tester, rig);
    expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '33°');
    await leave(tester);
  });

  testWidgets('uses the layout at laptop size too', (tester) async {
    final rig = Rig();
    await pumpAtSize(tester, const Size(1280, 800), rig.app());
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('belly-panel')), findsOneWidget);
    await leave(tester);
  });
}
