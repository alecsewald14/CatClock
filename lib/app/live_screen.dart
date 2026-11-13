import 'dart:async';

import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_controller.dart';
import '../weather/weather_repository.dart';
import 'cat_clock_screen.dart';

/// The address of the weather service's home page, for the credit link.
final Uri openMeteoHome = Uri.parse('https://open-meteo.com/');

/// The screen with the real clock and the real weather.
///
/// It owns nothing but the one-second tick: [weather] belongs to whoever created it.
/// The alarm shown is still a made-up sample until the alarm is wired in.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.weather,
    required this.openLink,
    required this.clock,
  });

  final WeatherRepository weather;

  /// Opens a web address in the person's browser.
  final Future<void> Function(Uri address) openLink;

  /// The device's local time. Replaced in tests.
  final DateTime Function() clock;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with WidgetsBindingObserver {
  late DateTime _now = widget.clock();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.weather.start());
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.weather,
      builder: (context, _) {
        final problem = widget.weather.problem;
        final notes = <String>[
          ?problem?.message,
          'Sample alarm, not working yet',
        ];
        return CatClockScreen(
          now: _now,
          colonOn: _now.second.isEven,
          weather: widget.weather.snapshot,
          freshness: widget.weather.freshness(),
          alarm: const Alarm(hour: 6, minute: 30, enabled: true),
          alarmState: AlarmState.armed,
          showAttribution: widget.weather.snapshot != null,
          onAttributionTap: () => widget.openLink(openMeteoHome),
          footerNote: notes.join('  ·  '),
        );
      },
    );
  }
}
