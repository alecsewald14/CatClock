import 'dart:async';

import 'package:flutter/material.dart';

import '../alarm/alarm_service.dart';
import '../clock/time_format.dart';
import '../platform/desktop_shell.dart';
import '../platform/startup_entry.dart';
import '../weather/weather_repository.dart';
import 'alarm_sheet.dart';
import 'app_settings.dart';
import 'cat_clock_screen.dart';

/// The address of the weather service's home page, for the credit link.
final Uri openMeteoHome = Uri.parse('https://open-meteo.com/');

/// The screen with the real clock, the real weather, and the working alarm.
///
/// It owns nothing but the one-second tick: the weather, the alarm, and the window shell
/// belong to whoever created them.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.weather,
    required this.alarm,
    required this.settingsStore,
    required this.settings,
    required this.openLink,
    required this.clock,
    this.shell,
    this.startupEntry,
    this.startHidden = false,
    this.pickTime = pickTimeWithMaterial,
  });

  final WeatherRepository weather;
  final AlarmService alarm;
  final AppSettingsStore settingsStore;

  /// What was saved last time, already loaded.
  final AppSettings settings;

  /// Opens a web address in the person's browser.
  final Future<void> Function(Uri address) openLink;

  /// The device's local time. Replaced in tests.
  final DateTime Function() clock;

  /// The window, tray icon, and taskbar. Null where there are none, as in most tests.
  final DesktopShell? shell;

  /// Starts the app at sign-in. Null hides that switch.
  final StartupEntry? startupEntry;

  /// Start with the window hidden in the tray, as when Windows starts the app at sign-in.
  final bool startHidden;

  final PickTime pickTime;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with WidgetsBindingObserver {
  late DateTime _now = widget.clock();
  late AppSettings _settings = widget.settings;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.weather.start());
    widget.alarm.start();
    unawaited(widget.shell?.start(
      onCloseRequested: _onCloseRequested,
      onQuitRequested: _onQuitRequested,
      startHidden: widget.startHidden,
    ));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = widget.clock());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(widget.weather.resume());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        widget.weather.pause();
      case AppLifecycleState.inactive:
        break; // just lost focus; still on screen
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  // ---- Window and tray ----

  /// Runs when the person closes the window. The first time, it explains that the app keeps
  /// running in the tray.
  Future<void> _onCloseRequested() async {
    if (_settings.trayNoticeSeen || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cat Clock keeps running'),
        content: const Text(
          'Closing the window keeps Cat Clock running in the tray, near the clock, so your '
          'alarm can still ring. To close it for good, right-click the cat icon there and '
          'choose Quit.',
        ),
        actions: [
          FilledButton(
            key: const Key('tray-notice-ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    _settings = _settings.copyWith(trayNoticeSeen: true);
    unawaited(widget.settingsStore.save(_settings).catchError((Object _) {}));
  }

  /// Runs when the person chooses Quit in the tray menu.
  Future<void> _onQuitRequested() async {
    if (!mounted) return;
    final alarm = widget.alarm.alarm;
    if (alarm.enabled) {
      final time = to12Hour(alarm.hour);
      final timeText = '${formatClockDigits(alarm.hour, alarm.minute)} ${time.isPm ? 'PM' : 'AM'}';
      final quit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quit Cat Clock?'),
          content: Text(
            'Quitting will cancel your $timeText alarm. It cannot ring unless Cat Clock '
            'is running.',
          ),
          actions: [
            TextButton(
              key: const Key('quit-keep'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep running'),
            ),
            FilledButton(
              key: const Key('quit-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Quit'),
            ),
          ],
        ),
      );
      if (quit != true) return;
    }
    await widget.shell?.quit();
  }

  void _openSheet() {
    showAlarmSheet(
      context,
      alarm: widget.alarm,
      startupEntry: widget.startupEntry,
      pickTime: widget.pickTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.weather, widget.alarm]),
      builder: (context, _) {
        final alarm = widget.alarm;
        return CatClockScreen(
          now: _now,
          colonOn: _now.second.isEven,
          weather: widget.weather.snapshot,
          freshness: widget.weather.freshness(),
          alarm: alarm.alarm,
          alarmState: alarm.state,
          snoozeUntil: alarm.snoozeUntil,
          missedAt: alarm.missedAt,
          soundProblem: alarm.soundProblem,
          showAttribution: widget.weather.snapshot != null,
          footerNote: widget.weather.problem?.message,
          onAlarmTap: _openSheet,
          onStop: alarm.stop,
          onSnooze: alarm.snooze,
          onDismissMissed: alarm.dismissMissed,
          onAttributionTap: () => widget.openLink(openMeteoHome),
        );
      },
    );
  }
}
