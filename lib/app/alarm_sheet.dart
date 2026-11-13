import 'dart:async';

import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_engine.dart';
import '../alarm/sound_catalog.dart';
import '../clock/time_format.dart';
import '../platform/startup_entry.dart';
import 'theme.dart';

/// Asks the person for a time of day. Replaced in tests.
typedef PickTime = Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> pickTimeWithMaterial(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
  );
}

/// Opens the alarm settings.
Future<void> showAlarmSheet(
  BuildContext context, {
  required AlarmEngine alarm,
  StartupEntry? startupEntry,
  String? note,
  PickTime pickTime = pickTimeWithMaterial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.barBackground,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => AlarmSheet(alarm: alarm, startupEntry: startupEntry, note: note, pickTime: pickTime),
  );
}

/// The alarm settings: the time, on or off, repeat, sound, volume, and (on Windows) whether
/// the app starts when you sign in.
class AlarmSheet extends StatefulWidget {
  const AlarmSheet({
    super.key,
    required this.alarm,
    this.startupEntry,
    this.note,
    this.pickTime = pickTimeWithMaterial,
  });

  final AlarmEngine alarm;

  /// A sentence about how the alarm behaves on this device, shown at the bottom.
  final String? note;

  /// Null where starting at sign-in does not apply, which hides the switch.
  final StartupEntry? startupEntry;

  final PickTime pickTime;

  @override
  State<AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<AlarmSheet> {
  bool? _startsWithWindows;
  String? _startupProblem;

  @override
  void initState() {
    super.initState();
    final entry = widget.startupEntry;
    if (entry != null) {
      unawaited(entry.isEnabled().then((enabled) {
        if (mounted) setState(() => _startsWithWindows = enabled);
      }).catchError((Object _) {
        if (mounted) setState(() => _startsWithWindows = false);
      }));
    }
  }

  Alarm get _current => widget.alarm.alarm;

  Future<void> _chooseTime() async {
    final picked = await widget.pickTime(
      context,
      TimeOfDay(hour: _current.hour, minute: _current.minute),
    );
    if (picked == null) return;
    // Choosing a time means you want that alarm, so it is switched on.
    widget.alarm.update(_current.copyWith(hour: picked.hour, minute: picked.minute, enabled: true));
  }

  Future<void> _setStartup(bool enabled) async {
    final entry = widget.startupEntry;
    if (entry == null) return;
    setState(() {
      _startsWithWindows = enabled;
      _startupProblem = null;
    });
    try {
      await entry.setEnabled(enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _startsWithWindows = !enabled;
        _startupProblem = 'Could not change this setting.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.alarm,
        builder: (context, _) {
          final alarm = widget.alarm.alarm;
          final time = to12Hour(alarm.hour);
          final timeText = '${formatClockDigits(alarm.hour, alarm.minute)} ${time.isPm ? 'PM' : 'AM'}';
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              key: const Key('alarm-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alarm',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.valueText,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('sheet-close'),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.labelText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('time-button'),
                  onPressed: _chooseTime,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    foregroundColor: AppColors.digitLit,
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800),
                  ),
                ),
                const Center(
                  child: Text(
                    'Tap the time to change it. Choosing a time turns the alarm on.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.labelText),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('switch-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alarm on', style: TextStyle(fontSize: 18)),
                  value: alarm.enabled,
                  onChanged: widget.alarm.setEnabled,
                ),
                SwitchListTile(
                  key: const Key('switch-repeat'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat every day', style: TextStyle(fontSize: 18)),
                  value: alarm.repeatDaily,
                  onChanged: (value) => widget.alarm.update(alarm.copyWith(repeatDaily: value)),
                ),
                const Divider(height: 28),
                const Text(
                  'Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.labelText),
                ),
                RadioGroup<String>(
                  groupValue: alarm.soundId,
                  onChanged: (id) {
                    if (id == null) return;
                    widget.alarm.update(alarm.copyWith(soundId: id));
                    unawaited(widget.alarm.preview(sound: soundById(id)));
                  },
                  child: Column(
                    children: [
                      for (final sound in alarmSounds)
                        RadioListTile<String>(
                          key: Key('sound-${sound.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: sound.id,
                          title: Text(sound.name, style: const TextStyle(fontSize: 17)),
                          secondary: IconButton(
                            key: Key('preview-${sound.id}'),
                            tooltip: 'Play ${sound.name}',
                            onPressed: () => unawaited(widget.alarm.preview(sound: sound)),
                            icon: const Icon(Icons.play_circle_outline, color: AppColors.digitLit),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 28),
                Text(
                  'Volume: level ${alarm.volumeLevel} of ${Alarm.maxVolumeLevel}',
                  key: const Key('volume-label'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.labelText),
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_down, color: AppColors.labelText),
                    Expanded(
                      child: Slider(
                        key: const Key('volume-slider'),
                        min: Alarm.minVolumeLevel.toDouble(),
                        max: Alarm.maxVolumeLevel.toDouble(),
                        divisions: Alarm.maxVolumeLevel - Alarm.minVolumeLevel,
                        value: alarm.volumeLevel.toDouble(),
                        label: '${alarm.volumeLevel}',
                        onChanged: (value) => widget.alarm.update(alarm.copyWith(volumeLevel: value.round())),
                        onChangeEnd: (_) => unawaited(widget.alarm.preview()),
                      ),
                    ),
                    const Icon(Icons.volume_up, color: AppColors.labelText),
                  ],
                ),
                const Text(
                  'Your computer\'s own volume still sets how loud the top level is.',
                  style: TextStyle(fontSize: 13, color: AppColors.labelText),
                ),
                if (widget.startupEntry != null) ...[
                  const Divider(height: 28),
                  SwitchListTile(
                    key: const Key('switch-startup'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start with Windows', style: TextStyle(fontSize: 18)),
                    subtitle: Text(
                      _startupProblem ?? 'Opens quietly in the tray when you sign in, so the alarm is ready.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _startupProblem != null ? const Color(0xFFFF8A80) : AppColors.labelText,
                      ),
                    ),
                    value: _startsWithWindows ?? false,
                    onChanged: _startsWithWindows == null ? null : _setStartup,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The alarm rings while Cat Clock is running. Closing the window keeps it running '
                    'in the tray. The laptop must be awake.',
                    key: Key('windows-note'),
                    style: TextStyle(fontSize: 13, color: AppColors.labelText),
                  ),
                ],
                if (widget.note != null) ...[
                  const Divider(height: 28),
                  Text(
                    widget.note!,
                    key: const Key('platform-note'),
                    style: const TextStyle(fontSize: 13, color: AppColors.labelText),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
