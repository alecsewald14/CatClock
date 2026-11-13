import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_controller.dart';
import '../alarm/sound_catalog.dart';
import '../clock/time_format.dart';
import 'theme.dart';

/// A sound's name for the screen: "Soft Chime". A sound this version does not know is
/// shown with its id tidied up, so "some_sound" becomes "Some Sound".
String soundDisplayName(String soundId) {
  if (isKnownSound(soundId)) return soundById(soundId).name;
  return soundId
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _clock(DateTime time) => formatUpdated(time.hour, time.minute);

/// The strip under the cat that shows the alarm: its time, whether it is on, and its
/// sound and volume. Tapping it opens the alarm settings.
///
/// While the alarm is snoozed it offers Stop, and after a missed alarm it offers Dismiss.
class AlarmBar extends StatelessWidget {
  const AlarmBar({
    super.key,
    required this.alarm,
    required this.state,
    this.snoozeUntil,
    this.missedAt,
    this.onTap,
    this.onStop,
    this.onDismissMissed,
  });

  final Alarm alarm;
  final AlarmState state;

  /// When a snoozed alarm rings again, in local time.
  final DateTime? snoozeUntil;

  /// When the missed alarm was due, in local time.
  final DateTime? missedAt;

  final VoidCallback? onTap;
  final VoidCallback? onStop;
  final VoidCallback? onDismissMissed;

  @override
  Widget build(BuildContext context) {
    final time = to12Hour(alarm.hour);
    final timeText = '${formatClockDigits(alarm.hour, alarm.minute)} ${time.isPm ? 'PM' : 'AM'}';
    final until = snoozeUntil;
    final missed = missedAt;
    final status = switch (state) {
      AlarmState.ringing => 'Ringing',
      AlarmState.snoozed => until != null ? 'Snoozed until ${_clock(until)}' : 'Snoozed',
      AlarmState.missed => missed != null ? 'Missed ${_clock(missed)}' : 'Missed',
      _ => null,
    };
    final details = <String>[
      ?status,
      soundDisplayName(alarm.soundId),
      'Volume ${alarm.volumeLevel} of ${Alarm.maxVolumeLevel}',
      if (alarm.repeatDaily) 'Every day',
    ].join('  ·  ');

    Widget trailing = _OnOffPill(on: alarm.enabled);
    if (state == AlarmState.snoozed && onStop != null) {
      trailing = TextButton(
        key: const Key('bar-stop'),
        onPressed: onStop,
        child: const Text('Stop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
    } else if (state == AlarmState.missed && onDismissMissed != null) {
      trailing = TextButton(
        key: const Key('bar-dismiss'),
        onPressed: onDismissMissed,
        child: const Text('Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
    }

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
                    trailing,
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
