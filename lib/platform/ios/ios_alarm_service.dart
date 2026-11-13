import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../alarm/alarm.dart';
import '../../alarm/alarm_controller.dart';
import '../../alarm/alarm_engine.dart';
import '../../alarm/alarm_store.dart';
import '../../alarm/sound_catalog.dart';
import '../../alarm/sound_player.dart';
import 'alarmkit_api.dart';

/// Runs the alarm on the iPhone. The system rings it, even with the app closed, the phone
/// locked, Silent on, or a Focus mode on; this class sets the alarm, mirrors its state on
/// screen, and saves the settings.
///
/// The system has no "missed" state, so [missedAt] is always null.
class IosAlarmService extends ChangeNotifier implements AlarmEngine {
  IosAlarmService({
    required this._alarm,
    required this._api,
    required this._store,
    required this._player,
    this.snoozeDuration = const Duration(minutes: 9),
  });

  /// Reads the saved alarm and builds a service around it.
  static Future<IosAlarmService> load({
    required AlarmKitApi api,
    required AlarmStore store,
    required SoundPlayer player,
  }) async {
    return IosAlarmService(alarm: await store.load(), api: api, store: store, player: player);
  }

  /// How long Snooze lasts.
  final Duration snoozeDuration;

  final AlarmKitApi _api;
  final AlarmStore _store;
  final SoundPlayer _player;

  Alarm _alarm;
  List<SystemAlarmState> _system = const [];
  String? _problem;
  bool _sawAlerting = false;
  bool _started = false;
  bool _disposed = false;
  StreamSubscription<List<SystemAlarmState>>? _subscription;

  // Operations run one after another, so setting and cancelling never overlap.
  Future<void> _queue = Future<void>.value();

  @override
  Alarm get alarm => _alarm;

  @override
  AlarmState get state {
    if (_system.contains(SystemAlarmState.alerting)) return AlarmState.ringing;
    if (_system.contains(SystemAlarmState.countdown) || _system.contains(SystemAlarmState.paused)) {
      return AlarmState.snoozed;
    }
    return _alarm.enabled ? AlarmState.armed : AlarmState.off;
  }

  @override
  DateTime? get snoozeUntil => null;

  @override
  DateTime? get missedAt => null;

  @override
  bool get soundProblem => false;

  @override
  String? get problem => _problem;

  /// The file the system plays for the current sound and volume level.
  String get soundFile => '${soundById(_alarm.soundId).id}_${_alarm.volumeLevel}.wav';

  // ---- Starting ----

  @override
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _api.updates.listen(_onSystemUpdate, onError: (Object _) {});
    unawaited(reconcile());
  }

  /// Compares what is saved with what the system holds. Call at start-up and each time the
  /// app comes back to the screen, since the alarm may have rung while the app was closed.
  Future<void> reconcile() {
    return _run(() async {
      List<SystemAlarmState> list;
      try {
        list = await _api.current();
      } catch (_) {
        return;
      }
      _system = list;
      _sawAlerting = list.contains(SystemAlarmState.alerting);
      if (_alarm.enabled && list.isEmpty) {
        if (_alarm.repeatDaily) {
          await _schedule();
        } else {
          // A one-time alarm that is no longer held has rung and is finished.
          await _saveAlarm(_alarm.copyWith(enabled: false));
        }
      }
    });
  }

  void _onSystemUpdate(List<SystemAlarmState> list) {
    if (_disposed) return;
    _system = list;
    final ringing = list.contains(SystemAlarmState.alerting);
    // A one-time alarm has finished once it has rung and then disappears.
    if (_sawAlerting && list.isEmpty && _alarm.enabled && !_alarm.repeatDaily) {
      _sawAlerting = false;
      unawaited(_run(() => _saveAlarm(_alarm.copyWith(enabled: false))));
    } else if (ringing) {
      _sawAlerting = true;
    } else if (list.isEmpty) {
      _sawAlerting = false;
    }
    notifyListeners();
  }

  // ---- Commands from the person ----

  @override
  void setEnabled(bool enabled) {
    unawaited(_run(() => _applyAlarm(_alarm.copyWith(enabled: enabled))));
  }

  @override
  void update(Alarm alarm) {
    unawaited(_run(() => _applyAlarm(alarm)));
  }

  @override
  void stop() {
    unawaited(_run(() async {
      try {
        await _api.stopAll();
      } catch (_) {}
    }));
  }

  @override
  void snooze() {
    unawaited(_run(() async {
      try {
        await _api.snoozeAll();
      } catch (_) {}
    }));
  }

  @override
  void dismissMissed() {}

  @override
  Future<void> preview({AlarmSound? sound, int? level}) async {
    if (state == AlarmState.ringing) return;
    try {
      await _player.playPreview(sound ?? soundById(_alarm.soundId), level ?? _alarm.volumeLevel);
    } catch (_) {
      // A sample that cannot play is not worth interrupting anything for.
    }
  }

  // ---- Inside ----

  Future<void> _run(Future<void> Function() action) {
    final next = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } finally {
        if (!_disposed) notifyListeners();
      }
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Saves [next] and brings the system alarm in line with it.
  Future<void> _applyAlarm(Alarm next) async {
    var wanted = next;
    final turningOn = wanted.enabled && !_alarm.enabled;
    if (turningOn && !await _ensurePermission()) {
      wanted = wanted.copyWith(enabled: false);
    }
    await _saveAlarm(wanted);
    if (wanted.enabled) {
      await _schedule();
    } else {
      await _cancel();
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      var permission = await _api.permission();
      if (permission == AlarmPermission.notDetermined) {
        permission = await _api.requestPermission();
      }
      if (permission == AlarmPermission.authorized) {
        _problem = null;
        return true;
      }
      _problem = 'Alarms are turned off for Cat Clock. Turn them on in the iPhone\'s Settings.';
      return false;
    } catch (_) {
      _problem = 'Could not ask for permission to set alarms.';
      return false;
    }
  }

  Future<void> _schedule() async {
    try {
      await _api.cancelAll();
      await _api.schedule(
        hour: _alarm.hour,
        minute: _alarm.minute,
        repeatDaily: _alarm.repeatDaily,
        soundFile: soundFile,
        snoozeSeconds: snoozeDuration.inSeconds,
      );
      _problem = null;
    } catch (_) {
      _problem = 'Could not set the alarm.';
      await _saveAlarm(_alarm.copyWith(enabled: false));
    }
  }

  Future<void> _cancel() async {
    try {
      await _api.cancelAll();
    } catch (_) {
      _problem = 'Could not cancel the alarm.';
    }
  }

  Future<void> _saveAlarm(Alarm next) async {
    _alarm = next;
    try {
      await _store.save(next);
    } catch (_) {
      // The alarm still works for this run even if it could not be saved.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
