import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alarm/alarm_engine.dart';
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
import 'platform/ios/alarmkit_api.dart';
import 'platform/ios/ios_alarm_service.dart';
import 'platform/signature_info.dart';
import 'platform/startup_entry.dart';
import 'platform/windows/problem_log.dart';
import 'platform/windows/registry_startup_entry.dart';
import 'platform/windows/single_instance.dart';
import 'platform/windows/windows_shell.dart';
import 'storage/text_storage.dart';
import 'weather/weather_repository.dart';
import 'weather/weather_setup.dart';

/// Said at the bottom of the alarm settings on the iPhone.
const String iosAlarmNote =
    'The alarm is set with the iPhone itself, so it rings even when the app is closed, the '
    'phone is locked, or Silent or a Focus mode is on. The volume steps above choose how '
    'loud the sound itself is, and the phone\'s own volume may change it too. An app '
    'installed this way works for 7 days, so renew it with AltStore before then, and keep '
    'a backup alarm in the Clock app for important mornings.';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataDirectory = await getApplicationSupportDirectory();
  final alarmStore = AlarmStore(FileTextStorage(File('${dataDirectory.path}/alarm.json')));
  final player = AudioplayersSoundPlayer();

  DesktopShell? shell;
  StartupEntry? startupEntry;
  SignatureInfo? signatureInfo;
  String? alarmNote;
  final AlarmEngine alarm;

  if (Platform.isIOS) {
    alarmNote = iosAlarmNote;
    signatureInfo = MethodChannelSignatureInfo();
    alarm = await IosAlarmService.load(api: MethodChannelAlarmKit(), store: alarmStore, player: player);
  } else {
    // Windows. Only one copy may run, or an alarm would ring twice.
    if (Platform.isWindows) {
      if (SingleInstance.acquire(dataDirectory) == null) {
        SingleInstance.showTheRunningCopy();
        exit(0);
      }
      final problemLog = ProblemLog(File('${dataDirectory.path}/problems.log'));
      shell = WindowsDesktopShell(log: problemLog.write);
      startupEntry = RegistryStartupEntry(executablePath: Platform.resolvedExecutable);
    }
    final windowShell = shell;
    alarm = await AlarmService.load(
      store: alarmStore,
      player: player,
      ticker: TimerSecondTicker(),
      nowUtc: () => DateTime.now().toUtc(),
      offsetAt: systemUtcOffsetAt,
      onRing: () {
        unawaited(windowShell?.alertUser());
      },
    );
  }

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
    signatureInfo: signatureInfo,
    alarmNote: alarmNote,
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
    this.signatureInfo,
    this.alarmNote,
    this.startHidden = false,
    this.openLink = _openInBrowser,
    this.clock = DateTime.now,
    this.pickTime = pickTimeWithMaterial,
  });

  /// Keeps the weather up to date. Replaced by a fake one in tests.
  final WeatherRepository weather;

  /// Runs the alarm. On Windows the app rings it; on the iPhone the system does.
  final AlarmEngine alarm;

  final AppSettingsStore settingsStore;
  final AppSettings settings;

  /// The window, tray icon, and taskbar. Null in tests and on the iPhone.
  final DesktopShell? shell;

  /// Starts the app at sign-in. Null hides that switch.
  final StartupEntry? startupEntry;

  /// When the iPhone signature expires. Null on Windows.
  final SignatureInfo? signatureInfo;

  /// A sentence about how the alarm behaves on this device.
  final String? alarmNote;

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
        signatureInfo: signatureInfo,
        alarmNote: alarmNote,
        startHidden: startHidden,
        openLink: openLink,
        clock: clock,
        pickTime: pickTime,
      ),
    );
  }
}
