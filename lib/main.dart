import 'dart:async';

import 'package:flutter/material.dart';

import 'alarm/alarm.dart';
import 'alarm/alarm_controller.dart';
import 'app/cat_clock_screen.dart';
import 'app/sample_weather.dart';
import 'app/theme.dart';
import 'weather/weather_rules.dart';

void main() {
  runApp(const CatClockApp());
}

class CatClockApp extends StatelessWidget {
  const CatClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Clock',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _PreviewScreen(),
    );
  }
}

/// A preview of the screen with the real clock, a made-up weather result, and a made-up
/// alarm. The live weather and the working alarm are added in later phases.
class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen();

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CatClockScreen(
      now: _now,
      colonOn: _now.second.isEven,
      weather: sampleWeather(_now),
      freshness: WeatherFreshness.fresh,
      alarm: const Alarm(hour: 6, minute: 30, enabled: true),
      alarmState: AlarmState.armed,
      showAttribution: false,
      footerNote: 'Sample weather and alarm, not live yet',
    );
  }
}
