import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alarm/alarm_service.dart';
import 'alarm/alarm_store.dart';
import 'alarm/audioplayers_sound_player.dart';
import 'alarm/next_fire_time.dart';
import 'alarm/second_ticker.dart';
import 'app/alarm_sheet.dart';
import 'app/app_settings.dart';
import 'app/live_screen.dart';
import 'app/theme.dart';
import 'platform/desktop_shell.dart';
import 'platform/startup_entry.dart';
import 'platform/windows/problem_log.dart';
import 'platform/windows/registry_startup_entry.dart';
import 'platform/windows/single_instance.dart';
import 'platform/windows/windows_shell.dart';
import 'storage/text_storage.dart';
import 'weather/weather_repository.dart';
import 'weather/weather_setup.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataDirectory = await getApplicationSupportDirectory();

  // Only one copy may run, or an alarm would ring twice.
  if (Platform.isWindows) {
    if (SingleInstance.acquire(dataDirectory) == null) {
      SingleInstance.showTheRunningCopy();
      exit(0);
    }
  }

  final problemLog = ProblemLog(File('${dataDirectory.path}/problems.log'));
  final DesktopShell? shell =
      Platform.isWindows ? WindowsDesktopShell(log: problemLog.write) : null;
  final StartupEntry? startupEntry = Platform.isWindows
      ? RegistryStartupEntry(executablePath: Platform.resolvedExecutable)
      : null;

  final alarm = await AlarmService.load(
    store: AlarmStore(FileTextStorage(File('${dataDirectory.path}/alarm.json'))),
    player: AudioplayersSoundPlayer(),
    ticker: TimerSecondTicker(),
    nowUtc: () => DateTime.now().toUtc(),
    offsetAt: systemUtcOffsetAt,
    onRing: () {
      unawaited(shell?.alertUser());
    },
  );

  final settingsStore = AppSettingsStore(
    FileTextStorage(File('${dataDirectory.path}/settings.json')),
  );

  runApp(CatClockApp(
    weather: createWeatherRepository(dataDirectory),
    alarm: alarm,
    settingsStore: settingsStore,
    settings: await settingsStore.load(),
    shell: shell,
    startupEntry: startupEntry,
    startHidden: arguments.contains('--hidden'),
  ));
}

Future<void> _openInBrowser(Uri address) async {
  await launchUrl(address, mode: LaunchMode.externalApplication);
}

class CatClockApp extends StatelessWidget {
  const CatClockApp({
    super.key,
    required this.weather,
    required this.alarm,
    required this.settingsStore,
    required this.settings,
    this.shell,
    this.startupEntry,
    this.startHidden = false,
    this.openLink = _openInBrowser,
    this.clock = DateTime.now,
    this.pickTime = pickTimeWithMaterial,
  });

  /// Keeps the weather up to date. Replaced by a fake one in tests.
  final WeatherRepository weather;

  /// Runs the alarm: the clock check, the sound, and the saved settings.
  final AlarmService alarm;

  final AppSettingsStore settingsStore;
  final AppSettings settings;

  /// The window, tray icon, and taskbar. Null in tests and on systems without them.
  final DesktopShell? shell;

  /// Starts the app at sign-in. Null hides that switch.
  final StartupEntry? startupEntry;

  final bool startHidden;

  /// Opens a web address in the person's browser. Replaced in tests.
  final Future<void> Function(Uri address) openLink;

  /// The device's local time. Replaced in tests.
  final DateTime Function() clock;

  /// Asks for a time of day. Replaced in tests.
  final PickTime pickTime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Clock',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: LiveScreen(
        weather: weather,
        alarm: alarm,
        settingsStore: settingsStore,
        settings: settings,
        shell: shell,
        startupEntry: startupEntry,
        startHidden: startHidden,
        openLink: openLink,
        clock: clock,
        pickTime: pickTime,
      ),
    );
  }
}
