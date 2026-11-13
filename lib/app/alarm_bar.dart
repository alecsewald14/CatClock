import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_controller.dart';
import '../clock/time_format.dart';
import 'theme.dart';

/// "soft_chime" becomes "Soft Chime".
String soundDisplayName(String soundId) {
  return soundId
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// The strip under the cat that shows the alarm: its time, whether it is on, and its
/// sound and volume. Tapping it opens the alarm settings.
class AlarmBar extends StatelessWidget {
  const AlarmBar({
    super.key,
    required this.alarm,
    required this.state,
    this.onTap,
  });

  final Alarm alarm;
  final AlarmState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = to12Hour(alarm.hour);
    final timeText = '${formatClockDigits(alarm.hour, alarm.minute)} ${time.isPm ? 'PM' : 'AM'}';
    final status = switch (state) {
      AlarmState.ringing => 'Ringing',
      AlarmState.snoozed => 'Snoozed',
      AlarmState.missed => 'Missed',
      _ => null,
    };
    final details = <String>[
      ?status,
      soundDisplayName(alarm.soundId),
      'Volume ${alarm.volumeLevel} of ${Alarm.maxVolumeLevel}',
      if (alarm.repeatDaily) 'Every day',
    ].join('  ·  ');

    return Semantics(
      button: true,
      label: 'Alarm $timeText, ${alarm.enabled ? 'on' : 'off'}. $details. Tap to change.',
      excludeSemantics: true,
      child: Material(
        key: const Key('alarm-bar'),
        color: AppColors.barBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 24,
                      color: alarm.enabled ? AppColors.digitLit : AppColors.labelText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Alarm  $timeText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.valueText,
                        ),
                      ),
                    ),
                    _OnOffPill(on: alarm.enabled),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  details,
                  key: const Key('alarm-details'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: state == AlarmState.missed
                        ? const Color(0xFFFF8A80)
                        : AppColors.labelText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnOffPill extends StatelessWidget {
  const _OnOffPill({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: on ? AppColors.switchOn : AppColors.switchOff,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        on ? 'ON' : 'OFF',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: on ? AppColors.background : AppColors.valueText,
        ),
      ),
    );
  }
}
