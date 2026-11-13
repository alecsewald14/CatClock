import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../weather/weather_models.dart';
import '../weather/weather_panel.dart';
import '../weather/weather_rules.dart';
import 'time_display.dart';

/// The screen on the cat's belly: the time on the left, the weather on the right.
///
/// It is always drawn at 960 by 420 design units and scaled as a whole, so the weather
/// stays to the right of the time on every screen size.
class BellyPanel extends StatelessWidget {
  const BellyPanel({
    super.key,
    required this.hour24,
    required this.minute,
    required this.colonOn,
    required this.weather,
    required this.freshness,
    required this.localNow,
  });

  final int hour24;
  final int minute;
  final bool colonOn;
  final WeatherSnapshot? weather;
  final WeatherFreshness freshness;
  final DateTime localNow;

  static const double width = 960;
  static const double height = 420;

  @override
  Widget build(BuildContext context) {
    // Phone text-size settings must not push the weather text out of its cells.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        key: const Key('belly-panel'),
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.panelBorder, width: 3),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: (height - TimeDisplay.digitsHeight) / 2,
                child: TimeDisplay(hour24: hour24, minute: minute, colonOn: colonOn),
              ),
              Positioned(
                left: 588,
                top: 36,
                bottom: 36,
                width: 2,
                child: ColoredBox(color: AppColors.digitLit.withValues(alpha: 0.18)),
              ),
              Positioned(
                left: 604,
                top: 12,
                child: WeatherPanel(
                  snapshot: weather,
                  freshness: freshness,
                  localNow: localNow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
