import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../clock/time_format.dart';
import 'weather_codes.dart';
import 'weather_icons.dart';
import 'weather_models.dart';
import 'weather_rules.dart';
import 'units.dart';

/// The weather beside the time: a large "Now" cell, then the next six hours.
///
/// Sizes are in design units; the whole screen is scaled to fit the device.
class WeatherPanel extends StatelessWidget {
  const WeatherPanel({
    super.key,
    required this.snapshot,
    required this.freshness,
    required this.localNow,
  });

  /// The last good weather, or null if there is none.
  final WeatherSnapshot? snapshot;

  /// Fresh shows normally, stale is dimmed, unavailable shows the "unavailable" picture.
  final WeatherFreshness freshness;

  /// The device's local time, used to label hours when there is no data.
  final DateTime localNow;

  static const double width = 336;
  static const double height = 396;
  static const double nowHeight = 96;
  static const double rowHeight = 140;
  static const double cellWidth = 104;
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final usable = data != null && freshness != WeatherFreshness.unavailable;

    final nowCell = usable
        ? _NowData(iconFor(data.now.code, isDay: data.now.isDay), formatTemperature(data.now.temperature))
        : const _NowData(WeatherIcon.unavailable, '--°');

    final cells = <_HourData>[];
    for (var i = 0; i < 6; i++) {
      if (usable && i < data.nextHours.length) {
        final hour = data.nextHours[i];
        cells.add(_HourData(
          hourLabel(hour.time.hour),
          iconFor(hour.code, isDay: hour.isDay),
          formatTemperature(hour.temperature),
        ));
      } else {
        cells.add(_HourData(hourLabel((localNow.hour + i + 1) % 24), WeatherIcon.unavailable, '--°'));
      }
    }

    return Opacity(
      opacity: freshness == WeatherFreshness.stale ? 0.5 : 1,
      child: SizedBox(
        key: const Key('weather-panel'),
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(height: nowHeight, child: _NowCell(data: nowCell)),
            const SizedBox(height: 8),
            _Row(cells: cells.sublist(0, 3), firstIndex: 0),
            const SizedBox(height: 8),
            _Row(cells: cells.sublist(3, 6), firstIndex: 3),
          ],
        ),
      ),
    );
  }
}

class _NowData {
  const _NowData(this.icon, this.temperature);
  final WeatherIcon icon;
  final String temperature;
}

class _HourData {
  const _HourData(this.label, this.icon, this.temperature);
  final String label;
  final WeatherIcon icon;
  final String temperature;
}

class _NowCell extends StatelessWidget {
  const _NowCell({required this.data});

  final _NowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('now-cell'),
      children: [
        SizedBox(
          key: const Key('now-icon'),
          width: 80,
          height: 80,
          child: CustomPaint(painter: WeatherIconPainter(data.icon)),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NOW',
              style: TextStyle(
                fontSize: 30,
                height: 1,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.labelText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.temperature,
              key: const Key('now-temp'),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 56,
                height: 1,
                fontWeight: FontWeight.w600,
                color: AppColors.valueText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.cells, required this.firstIndex});

  final List<_HourData> cells;
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WeatherPanel.rowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < cells.length; i++)
            _HourCell(index: firstIndex + i, data: cells[i]),
        ],
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({required this.index, required this.data});

  final int index;
  final _HourData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('hour-cell-$index'),
      width: WeatherPanel.cellWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.label,
            key: Key('hour-label-$index'),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontSize: 32,
              height: 1,
              fontWeight: FontWeight.w500,
              color: AppColors.labelText,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            key: Key('hour-icon-$index'),
            width: 62,
            height: 62,
            child: CustomPaint(painter: WeatherIconPainter(data.icon)),
          ),
          const SizedBox(height: 4),
          Text(
            data.temperature,
            key: Key('hour-temp-$index'),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.valueText,
            ),
          ),
        ],
      ),
    );
  }
}
