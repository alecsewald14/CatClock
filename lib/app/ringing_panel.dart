import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../clock/time_format.dart';
import 'theme.dart';

/// Shown in place of the alarm strip while the alarm is ringing: two big buttons.
class RingingPanel extends StatelessWidget {
  const RingingPanel({
    super.key,
    required this.alarm,
    required this.onStop,
    required this.onSnooze,
    this.soundProblem = false,
    this.snoozeMinutes = 9,
  });

  final Alarm alarm;
  final VoidCallback onStop;
  final VoidCallback onSnooze;

  /// True if the alarm sound could not be played, so the person knows why it is quiet.
  final bool soundProblem;

  final int snoozeMinutes;

  @override
  Widget build(BuildContext context) {
    final time = to12Hour(alarm.hour);
    final timeText = '${formatClockDigits(alarm.hour, alarm.minute)} ${time.isPm ? 'PM' : 'AM'}';
    return Semantics(
      liveRegion: true,
      label: 'Alarm ringing, $timeText. Stop or snooze.',
      child: Material(
        key: const Key('ringing-panel'),
        color: AppColors.barBackground,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm, size: 26, color: AppColors.digitLit),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Alarm  $timeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.valueText,
                      ),
                    ),
                  ),
                ],
              ),
              if (soundProblem) ...[
                const SizedBox(height: 6),
                const Text(
                  'The alarm sound could not be played.',
                  key: Key('sound-problem'),
                  style: TextStyle(fontSize: 14, color: Color(0xFFFF8A80)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('stop-button'),
                      onPressed: onStop,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        backgroundColor: AppColors.digitLit,
                        foregroundColor: AppColors.background,
                        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Stop'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('snooze-button'),
                      onPressed: onSnooze,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        foregroundColor: AppColors.valueText,
                        side: const BorderSide(color: AppColors.labelText, width: 1.5),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      child: Text('Snooze $snoozeMinutes min'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
