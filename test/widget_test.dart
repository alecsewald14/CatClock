import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_controller.dart';
import 'package:cat_clock/alarm/alarm_service.dart';
import 'package:cat_clock/alarm/alarm_store.dart';
import 'package:cat_clock/app/app_settings.dart';
import 'package:cat_clock/main.dart';
import 'package:cat_clock/storage/text_storage.dart';
import 'package:cat_clock/weather/location_service.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_cache.dart';
import 'package:cat_clock/weather/weather_problem.dart';
import 'package:cat_clock/weather/weather_repository.dart';

import 'helpers/alarm_fakes.dart';
import 'helpers/app_fakes.dart';
import 'helpers/pump.dart';
import 'helpers/weather_fakes.dart';

/// 12:34 PM local time on a Thursday, with an odd second so the colon is off.
final fixedNow = DateTime(2026, 11, 12, 12, 34, 5);
final utcNow = DateTime.utc(2026, 11, 12, 17, 34, 5);

/// An alarm that rings 30 seconds after [utcNow] when the offset is zero.
final ringAt = DateTime.utc(2026, 11, 12, 17, 35);
const ringingAlarm = Alarm(hour: 17, minute: 35, enabled: true, soundId: 'cat_bell', volumeLevel: 4);

class Rig {
  Rig._({
    required this.repo,
    required this.alarm,
    required this.shell,
    required this.startup,
    required this.player,
    required this.ticker,
    required this.alarmStorage,
    required this.settingsStorage,
    required this.weatherClock,
    required this.alarmClock,
    required this.scheduler,
    required this.fetcher,
  });

  final WeatherRepository repo;
  final AlarmService alarm;
  final FakeShell shell;
  final FakeStartupEntry startup;
  final FakeSoundPlayer player;
  final FakeTicker ticker;
  final MemoryTextStorage alarmStorage;
  final MemoryTextStorage settingsStorage;
  final FakeClock weatherClock;
  final FakeScheduler scheduler;
  final FakeFetcher fetcher;
  final FakeClock alarmClock;
  final List<Uri> opened = [];
  TimeOfDay? timeToPick;

  static Future<Rig> create({
    Alarm? savedAlarm,
    List<LocationResult>? location,
    List<Object>? outcomes,
    TextStorage? weatherStorage,
    AppSettings settings = const AppSettings(),
    bool startupEnabled = false,
  }) async {
    final weatherClock = FakeClock(utcNow);
    final scheduler = FakeScheduler();
    final fetcher = FakeFetcher(outcomes ?? [snapshotAt(utcNow)]);
    final repo = WeatherRepository(
      location: FakeLocation(location ?? [const LocationFound(40.7128, -74.0060)]),
      fetcher: fetcher,
      cache: WeatherCache(weatherStorage ?? MemoryTextStorage()),
      nowUtc: weatherClock.call,
      unit: () => TemperatureUnit.fahrenheit,
      scheduler: scheduler,
    );

    final alarmStorage = MemoryTextStorage();
    if (savedAlarm != null) await AlarmStore(alarmStorage).save(savedAlarm);
    final player = FakeSoundPlayer();
    final ticker = FakeTicker();
    final shell = FakeShell();
    final alarmClock = FakeClock(utcNow);
    final alarm = await AlarmService.load(
      store: AlarmStore(alarmStorage),
      player: player,
      ticker: ticker,
      nowUtc: alarmClock.call,
      offsetAt: (_) => Duration.zero,
      onRing: () => shell.alertUser(),
    );
    final settingsStorage = MemoryTextStorage();
    await AppSettingsStore(settingsStorage).save(settings);

    return Rig._(
      repo: repo,
      alarm: alarm,
      shell: shell,
      startup: FakeStartupEntry(enabled: startupEnabled),
      player: player,
      ticker: ticker,
      alarmStorage: alarmStorage,
      settingsStorage: settingsStorage,
      weatherClock: weatherClock,
      alarmClock: alarmClock,
      scheduler: scheduler,
      fetcher: fetcher,
    );
  }

  /// Moves the alarm's clock to [time] and ticks once.
  Future<void> alarmTickAt(WidgetTester tester, DateTime time) async {
    alarmClock.now = time;
    ticker.tick();
    await tester.pump();
  }

  Widget app({DateTime Function()? clock}) => CatClockApp(
        weather: repo,
        alarm: alarm,
        settingsStore: AppSettingsStore(settingsStorage),
        settings: const AppSettings(),
        shell: shell,
        startupEntry: startup,
        openLink: (uri) async => opened.add(uri),
        clock: clock ?? () => fixedNow,
        pickTime: (context, initial) async => timeToPick,
      );
}

Future<void> showApp(WidgetTester tester, Rig rig, {DateTime Function()? clock, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(rig.app(clock: clock));
  await tester.pump();
  await tester.pump();
}

Future<void> leave(WidgetTester tester) async {
  // Leave the screen so the timers are cancelled.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  group('the app', () {
    testWidgets('opens on the cat clock screen with the real time', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      expect(find.byKey(const Key('belly-panel')), findsOneWidget);
      expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
      expect(find.byKey(const Key('cat')), findsOneWidget);
      expect(find.bySemanticsLabel('Time 12:34 PM'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('starts the weather, the alarm check, and the window shell', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      expect(rig.fetcher.requests.length, 1);
      expect(rig.ticker.running, isTrue);
      expect(rig.shell.startCount, 1);
      expect(rig.shell.startedHidden, isFalse);
      await leave(tester);
    });

    testWidgets('shows the weather that was fetched', (tester) async {
      final rig = await Rig.create(outcomes: [snapshotAt(utcNow, temperature: 61)]);
      await showApp(tester, rig);
      expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '61°');
      expect(tester.widget<Text>(find.byKey(const Key('hour-label-0'))).data, '1PM');
      await leave(tester);
    });

    testWidgets('shows the Open-Meteo credit, and tapping it opens their home page', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await tester.tap(find.byKey(const Key('attribution')));
      expect(rig.opened, [Uri.parse('https://open-meteo.com/')]);
      await leave(tester);
    });

    testWidgets('says plainly when location is off, and the clock and alarm still work', (tester) async {
      final rig = await Rig.create(
        location: [const LocationFailed(WeatherProblem.locationDisabled)],
        savedAlarm: ringingAlarm,
      );
      await showApp(tester, rig);
      expect(tester.widget<Text>(find.byKey(const Key('note'))).data, contains('location is turned off'));
      expect(tester.widget<Text>(find.byKey(const Key('now-temp'))).data, '--°');
      expect(find.bySemanticsLabel('Time 12:34 PM'), findsOneWidget);
      expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
      await leave(tester);
    });

    testWidgets('dims old weather and shows when it was last updated', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      rig.weatherClock.now = utcNow.add(const Duration(minutes: 31));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('updated')), findsOneWidget);
      final weatherOpacity = find.ancestor(
        of: find.byKey(const Key('weather-panel')),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(weatherOpacity.first).opacity, 0.5);
      await leave(tester);
    });

    testWidgets('stops refreshing weather when hidden, and refreshes when it comes back', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(rig.scheduler.pending, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(rig.fetcher.requests.length, 2);
      await leave(tester);
    });

    testWidgets('starts hidden when told to, as when Windows starts it at sign-in', (tester) async {
      final rig = await Rig.create();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CatClockApp(
        weather: rig.repo,
        alarm: rig.alarm,
        settingsStore: AppSettingsStore(rig.settingsStorage),
        settings: const AppSettings(),
        shell: rig.shell,
        startHidden: true,
        clock: () => fixedNow,
      ));
      expect(rig.shell.startedHidden, isTrue);
      await leave(tester);
    });

    testWidgets('works at laptop size', (tester) async {
      final rig = await Rig.create();
      await pumpAtSize(tester, const Size(1280, 800), rig.app());
      await tester.pump();
      expect(find.byKey(const Key('belly-panel')), findsOneWidget);
      await leave(tester);
    });
  });

  group('the alarm settings', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('alarm-bar')));
      await tester.pumpAndSettle();
    }

    testWidgets('open when the alarm strip is tapped', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await openSheet(tester);
      expect(find.byKey(const Key('alarm-sheet')), findsOneWidget);
      expect(find.text('5:35 PM'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('closing the sheet works', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('sheet-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alarm-sheet')), findsNothing);
      await leave(tester);
    });

    testWidgets('choosing a time sets it, turns the alarm on, and saves it', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      rig.timeToPick = const TimeOfDay(hour: 6, minute: 45);
      await tester.tap(find.byKey(const Key('time-button')));
      await tester.pumpAndSettle();
      expect(rig.alarm.alarm.hour, 6);
      expect(rig.alarm.alarm.minute, 45);
      expect(rig.alarm.alarm.enabled, isTrue);
      expect(find.text('6:45 AM'), findsWidgets);
      expect((await AlarmStore(rig.alarmStorage).load()).minute, 45);
      await leave(tester);
    });

    testWidgets('cancelling the time picker changes nothing', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await openSheet(tester);
      rig.timeToPick = null;
      await tester.tap(find.byKey(const Key('time-button')));
      await tester.pumpAndSettle();
      expect(rig.alarm.alarm, ringingAlarm);
      await leave(tester);
    });

    testWidgets('the on/off switch turns the alarm on and off', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('switch-enabled')));
      await tester.pumpAndSettle();
      expect(rig.alarm.state, AlarmState.armed);
      await tester.tap(find.byKey(const Key('switch-enabled')));
      await tester.pumpAndSettle();
      expect(rig.alarm.state, AlarmState.off);
      await leave(tester);
    });

    testWidgets('the repeat switch is saved', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('switch-repeat')));
      await tester.pumpAndSettle();
      expect(rig.alarm.alarm.repeatDaily, isTrue);
      expect((await AlarmStore(rig.alarmStorage).load()).repeatDaily, isTrue);
      await leave(tester);
    });

    testWidgets('lists the six sounds, and choosing one saves it and plays a sample', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      for (final id in ['soft_chime', 'classic_beep', 'morning_bells', 'purr_rise', 'meow_melody', 'cat_bell']) {
        expect(find.byKey(Key('sound-$id')), findsOneWidget, reason: id);
      }
      await tester.ensureVisible(find.byKey(const Key('sound-meow_melody')));
      await tester.tap(find.byKey(const Key('sound-meow_melody')));
      await tester.pumpAndSettle();
      expect(rig.alarm.alarm.soundId, 'meow_melody');
      expect(rig.player.events, contains('preview:meow_melody:3'));
      await leave(tester);
    });

    testWidgets('the play button gives a sample without choosing the sound', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      await tester.ensureVisible(find.byKey(const Key('preview-purr_rise')));
      await tester.tap(find.byKey(const Key('preview-purr_rise')));
      await tester.pumpAndSettle();
      expect(rig.player.events, ['preview:purr_rise:3']);
      expect(rig.alarm.alarm.soundId, 'soft_chime');
      await leave(tester);
    });

    testWidgets('the volume slider has five steps, saves the level, and plays a sample when released', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      final slider = find.byKey(const Key('volume-slider'));
      await tester.ensureVisible(slider);
      expect(tester.widget<Slider>(slider).divisions, 4);
      expect(tester.widget<Slider>(slider).min, 1);
      expect(tester.widget<Slider>(slider).max, 5);

      final rect = tester.getRect(slider);
      // Drag from the middle to the far right: level 5.
      await tester.dragFrom(rect.center, Offset(rect.width, 0));
      await tester.pumpAndSettle();
      expect(rig.alarm.alarm.volumeLevel, 5);
      expect(find.text('Volume: level 5 of 5'), findsOneWidget);
      expect(rig.player.events.last, startsWith('preview:soft_chime:5'));
      await leave(tester);
    });

    testWidgets('the Start with Windows switch shows the current setting', (tester) async {
      final rig = await Rig.create(startupEnabled: true);
      await showApp(tester, rig);
      await openSheet(tester);
      final switchTile = find.byKey(const Key('switch-startup'));
      await tester.ensureVisible(switchTile);
      expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
      await leave(tester);
    });

    testWidgets('the Start with Windows switch turns it on and off', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      final switchTile = find.byKey(const Key('switch-startup'));
      await tester.ensureVisible(switchTile);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(rig.startup.enabled, isTrue);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(rig.startup.enabled, isFalse);
      expect(rig.startup.changes, [true, false]);
      await leave(tester);
    });

    testWidgets('a failure to change Start with Windows puts the switch back and says so', (tester) async {
      final rig = await Rig.create();
      rig.startup.failNextChange = true;
      await showApp(tester, rig);
      await openSheet(tester);
      final switchTile = find.byKey(const Key('switch-startup'));
      await tester.ensureVisible(switchTile);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
      expect(find.text('Could not change this setting.'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the Start with Windows switch is shown off if the setting cannot be read', (tester) async {
      final rig = await Rig.create();
      rig.startup.failToRead = true;
      await showApp(tester, rig);
      await openSheet(tester);
      final switchTile = find.byKey(const Key('switch-startup'));
      await tester.ensureVisible(switchTile);
      expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
      await leave(tester);
    });

    testWidgets('the sheet explains that the laptop must be awake and the app running', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await openSheet(tester);
      await tester.ensureVisible(find.byKey(const Key('windows-note')));
      expect(find.byKey(const Key('windows-note')), findsOneWidget);
      await leave(tester);
    });
  });

  group('when the alarm rings', () {
    testWidgets('the Stop and Snooze buttons replace the alarm strip, the sound plays, and the window comes forward', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      expect(find.byKey(const Key('ringing-panel')), findsNothing);

      await rig.alarmTickAt(tester, ringAt);
      expect(find.byKey(const Key('ringing-panel')), findsOneWidget);
      expect(find.byKey(const Key('alarm-bar')), findsNothing);
      expect(find.byKey(const Key('stop-button')), findsOneWidget);
      expect(find.text('Snooze 9 min'), findsOneWidget);
      expect(rig.player.events, ['alarm:cat_bell:4']);
      expect(rig.shell.alertCount, 1);
      await leave(tester);
    });

    testWidgets('Stop silences the alarm and brings the strip back, turned off', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      await tester.tap(find.byKey(const Key('stop-button')));
      await tester.pump();
      expect(find.byKey(const Key('ringing-panel')), findsNothing);
      expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(rig.player.alarmIsPlaying, isFalse);
      await leave(tester);
    });

    testWidgets('Snooze silences the alarm, shows when it rings again, and offers Stop', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      await tester.tap(find.byKey(const Key('snooze-button')));
      await tester.pump();
      expect(rig.player.alarmIsPlaying, isFalse);
      expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
      final details = tester.widget<Text>(find.byKey(const Key('alarm-details'))).data!;
      expect(details, matches(RegExp(r'^Snoozed until \d{1,2}:\d{2} (AM|PM)')));
      expect(find.byKey(const Key('bar-stop')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bar-stop')));
      await tester.pump();
      expect(find.text('OFF'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('after the snooze it rings again and the window comes forward again', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      await tester.tap(find.byKey(const Key('snooze-button')));
      await tester.pump();
      await rig.alarmTickAt(tester, ringAt.add(const Duration(minutes: 9)));
      expect(find.byKey(const Key('ringing-panel')), findsOneWidget);
      expect(rig.shell.alertCount, 2);
      await leave(tester);
    });

    testWidgets('an unanswered alarm becomes missed, and Dismiss clears it', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      await rig.alarmTickAt(tester, ringAt.add(const Duration(minutes: 10)));
      expect(find.byKey(const Key('ringing-panel')), findsNothing);
      final details = tester.widget<Text>(find.byKey(const Key('alarm-details'))).data!;
      expect(details, startsWith('Missed '));
      expect(find.byKey(const Key('bar-dismiss')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bar-dismiss')));
      await tester.pump();
      expect(find.byKey(const Key('bar-dismiss')), findsNothing);
      expect(find.text('OFF'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('says so when the alarm sound cannot be played', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      rig.player.failToPlayAlarm = true;
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      await tester.pump();
      expect(find.byKey(const Key('sound-problem')), findsOneWidget);
      expect(find.byKey(const Key('stop-button')), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the time digits pulse on the off seconds while it rings', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      // 12:34:05 has an odd second, so the colon is off.
      await showApp(tester, rig);
      await rig.alarmTickAt(tester, ringAt);
      expect(tester.widget<Opacity>(find.byKey(const Key('time-pulse'))).opacity, 0.3);
      await leave(tester);
    });

    testWidgets('and are bright on the on seconds', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig, clock: () => DateTime(2026, 11, 12, 12, 34, 4));
      await rig.alarmTickAt(tester, ringAt);
      expect(tester.widget<Opacity>(find.byKey(const Key('time-pulse'))).opacity, 1);
      await leave(tester);
    });

    testWidgets('stay steady when the device\'s "reduce motion" setting is on', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(390, 844)),
        child: rig.app(),
      ));
      await tester.pump();
      await rig.alarmTickAt(tester, ringAt);
      expect(tester.widget<Opacity>(find.byKey(const Key('time-pulse'))).opacity, 1);
      await leave(tester);
    });

    testWidgets('the digits do not pulse when the alarm is not ringing', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      expect(tester.widget<Opacity>(find.byKey(const Key('time-pulse'))).opacity, 1);
      await leave(tester);
    });
  });

  group('closing and quitting', () {
    testWidgets('closing the window the first time explains that the app keeps running', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      final closing = rig.shell.requestClose();
      await tester.pumpAndSettle();
      expect(find.text('Cat Clock keeps running'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tray-notice-ok')));
      await tester.pumpAndSettle();
      await closing;
      final saved = await AppSettingsStore(rig.settingsStorage).load();
      expect(saved.trayNoticeSeen, isTrue);
      await leave(tester);
    });

    testWidgets('the notice is not shown again once it has been seen', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      final first = rig.shell.requestClose();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tray-notice-ok')));
      await tester.pumpAndSettle();
      await first;

      await rig.shell.requestClose();
      await tester.pumpAndSettle();
      expect(find.text('Cat Clock keeps running'), findsNothing);
      await leave(tester);
    });

    testWidgets('the notice is not shown when it was seen in an earlier run', (tester) async {
      final rig = await Rig.create();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CatClockApp(
        weather: rig.repo,
        alarm: rig.alarm,
        settingsStore: AppSettingsStore(rig.settingsStorage),
        settings: const AppSettings(trayNoticeSeen: true),
        shell: rig.shell,
        clock: () => fixedNow,
      ));
      await tester.pump();
      await rig.shell.requestClose();
      await tester.pumpAndSettle();
      expect(find.text('Cat Clock keeps running'), findsNothing);
      await leave(tester);
    });

    testWidgets('quitting with the alarm on asks first, and Keep running does not quit', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      final quitting = rig.shell.requestQuit();
      await tester.pumpAndSettle();
      expect(find.text('Quit Cat Clock?'), findsOneWidget);
      expect(find.textContaining('cancel your 5:35 PM alarm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quit-keep')));
      await tester.pumpAndSettle();
      await quitting;
      expect(rig.shell.quitCount, 0);
      await leave(tester);
    });

    testWidgets('quitting with the alarm on quits once confirmed', (tester) async {
      final rig = await Rig.create(savedAlarm: ringingAlarm);
      await showApp(tester, rig);
      final quitting = rig.shell.requestQuit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quit-confirm')));
      await tester.pumpAndSettle();
      await quitting;
      expect(rig.shell.quitCount, 1);
      await leave(tester);
    });

    testWidgets('quitting with the alarm off quits straight away', (tester) async {
      final rig = await Rig.create();
      await showApp(tester, rig);
      await rig.shell.requestQuit();
      await tester.pumpAndSettle();
      expect(find.text('Quit Cat Clock?'), findsNothing);
      expect(rig.shell.quitCount, 1);
      await leave(tester);
    });
  });
}
