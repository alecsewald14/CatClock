import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_controller.dart';
import '../cat/walk_cycle.dart';
import '../clock/time_format.dart';
import '../weather/weather_models.dart';
import '../weather/weather_rules.dart';
import 'alarm_bar.dart';
import 'cat_scene.dart';
import 'theme.dart';

/// The whole screen: the walking cat with the time and weather on its belly, the alarm
/// strip, and a footer with the weather credit.
class CatClockScreen extends StatelessWidget {
  const CatClockScreen({
    super.key,
    required this.now,
    required this.weather,
    required this.freshness,
    required this.alarm,
    required this.alarmState,
    this.colonOn = true,
    this.animateCat = true,
    this.catPose,
    this.onAlarmTap,
    this.onAttributionTap,
    this.showAttribution = true,
    this.footerNote,
  });

  /// The device's local time.
  final DateTime now;

  final WeatherSnapshot? weather;
  final WeatherFreshness freshness;
  final Alarm alarm;
  final AlarmState alarmState;

  /// The colon blinks once a second; the caller flips this every second.
  final bool colonOn;

  final bool animateCat;

  /// Optional pose holder, so tests can look at every frame.
  final ValueNotifier<CatPose>? catPose;

  final VoidCallback? onAlarmTap;
  final VoidCallback? onAttributionTap;

  /// The Open-Meteo licence needs a credit link next to real weather. Turn it off only
  /// when the weather shown is made up.
  final bool showAttribution;

  /// An extra line of small print, for example "Sample weather, not live".
  final String? footerNote;

  @override
  Widget build(BuildContext context) {
    final data = weather;
    String? updated;
    if (data != null && freshness == WeatherFreshness.stale) {
      final fetched = data.fetchedAtUtc.toLocal();
      updated = 'updated ${formatUpdated(fetched.hour, fetched.minute)}';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: CatScene(
                      hour24: now.hour,
                      minute: now.minute,
                      colonOn: colonOn,
                      weather: weather,
                      freshness: freshness,
                      localNow: now,
                      animate: animateCat,
                      pose: catPose,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AlarmBar(alarm: alarm, state: alarmState, onTap: onAlarmTap),
              const SizedBox(height: 8),
              ScreenFooter(
                showAttribution: showAttribution,
                updatedText: updated,
                note: footerNote,
                onAttributionTap: onAttributionTap,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small print under the alarm strip: the weather credit, how old the weather is, and
/// any note.
class ScreenFooter extends StatelessWidget {
  const ScreenFooter({
    super.key,
    this.showAttribution = true,
    this.updatedText,
    this.note,
    this.onAttributionTap,
  });

  final bool showAttribution;
  final String? updatedText;
  final String? note;
  final VoidCallback? onAttributionTap;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.labelText);
    return Wrap(
      key: const Key('footer'),
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 2,
      children: [
        if (showAttribution)
          Semantics(
            link: true,
            child: GestureDetector(
              onTap: onAttributionTap,
              child: const Text(
                'Weather data by Open-Meteo.com',
                key: Key('attribution'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.labelText,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.labelText,
                ),
              ),
            ),
          ),
        if (updatedText != null) Text(updatedText!, key: const Key('updated'), style: style),
        if (note != null) Text(note!, key: const Key('note'), style: style),
      ],
    );
  }
}
