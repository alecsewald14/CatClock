import 'package:flutter/foundation.dart';

import 'alarm.dart';
import 'next_fire_time.dart';

/// Where the alarm is in its life.
enum AlarmState {
  /// Switched off.
  off,

  /// Waiting for its time to come.
  armed,

  /// Sounding now.
  ringing,

  /// Silenced for a few minutes, and will sound again.
  snoozed,

  /// Nobody answered in time. Shows "Alarm missed" until dismissed.
  missed,
}

/// Decides what the alarm should be doing, second by second.
///
/// It only decides; it does not play sound or touch the screen. The Windows app calls
/// [tick] every second. On the iPhone the system rings the alarm, and this class mainly
/// tracks the alarm's settings.
///
/// Rules (from the design spec):
/// * The alarm rings when its time arrives. If the laptop was asleep and wakes within
///   10 minutes after, it rings at once; later than that it is missed.
/// * Snooze waits 9 minutes. A ringing alarm nobody answers for 10 minutes becomes missed.
/// * Stop turns a one-time alarm off. With daily repeat it re-arms for tomorrow.
class AlarmController extends ChangeNotifier {
  AlarmController({
    required Alarm alarm,
    required this._nowUtc,
    required this._offsetAt,
    this.snoozeDuration = const Duration(minutes: 9),
    this.ringLimit = const Duration(minutes: 10),
    this.lateLimit = const Duration(minutes: 10),
  }) : _alarm = alarm {
    if (alarm.enabled) {
      _state = AlarmState.armed;
      _fireAt = _computeNext();
    }
  }

  /// How long a snooze lasts.
  final Duration snoozeDuration;

  /// How long an unanswered alarm keeps ringing before it counts as missed.
  final Duration ringLimit;

  /// How late an alarm may still ring, for example after the laptop wakes from sleep.
  final Duration lateLimit;

  final DateTime Function() _nowUtc;
  final UtcOffsetAt _offsetAt;

  Alarm _alarm;
  AlarmState _state = AlarmState.off;
  DateTime? _fireAt;
  DateTime? _snoozeUntil;
  DateTime? _missedAt;
  DateTime? _ringStartedAt;

  /// The moment the alarm was originally due, kept while it rings or is snoozed so a miss
  /// can report the right time.
  DateTime? _scheduledFor;

  Alarm get alarm => _alarm;
  AlarmState get state => _state;

  /// When the alarm will next ring. Null unless armed, or missed with daily repeat.
  DateTime? get fireAt => _fireAt;

  /// When a snoozed alarm will ring again.
  DateTime? get snoozeUntil => _snoozeUntil;

  /// When the missed alarm was due, while [state] is [AlarmState.missed].
  DateTime? get missedAt => _missedAt;

  DateTime _now() {
    final now = _nowUtc();
    return now.isUtc ? now : now.toUtc();
  }

  DateTime _computeNext() => nextFireTime(
        nowUtc: _now(),
        hour: _alarm.hour,
        minute: _alarm.minute,
        offsetAt: _offsetAt,
      );

  // ---- Commands from the person ----

  /// Turns the alarm on. Does nothing while it is ringing or snoozed.
  void arm() {
    if (_state == AlarmState.ringing || _state == AlarmState.snoozed) return;
    _alarm = _alarm.copyWith(enabled: true);
    _armFromScratch();
    notifyListeners();
  }

  /// Turns the alarm fully off, even if it is ringing and set to repeat daily.
  void disarm() {
    if (_state == AlarmState.off && !_alarm.enabled) return;
    _alarm = _alarm.copyWith(enabled: false);
    _clearCycle();
    _state = AlarmState.off;
    notifyListeners();
  }

  /// Stops a ringing or snoozed alarm.
  void stop() {
    if (_state != AlarmState.ringing && _state != AlarmState.snoozed) return;
    _clearCycle();
    if (_alarm.repeatDaily) {
      _state = AlarmState.armed;
      _fireAt = _computeNext();
    } else {
      _alarm = _alarm.copyWith(enabled: false);
      _state = AlarmState.off;
    }
    notifyListeners();
  }

  /// Silences a ringing alarm for [snoozeDuration].
  void snooze() {
    if (_state != AlarmState.ringing) return;
    _state = AlarmState.snoozed;
    _snoozeUntil = _now().add(snoozeDuration);
    _ringStartedAt = null;
    notifyListeners();
  }

  /// Clears the "alarm missed" notice.
  void dismissMissed() {
    if (_state != AlarmState.missed) return;
    _missedAt = null;
    if (_alarm.repeatDaily) {
      _state = AlarmState.armed;
      _fireAt = _computeNext();
    } else {
      _state = AlarmState.off;
      _fireAt = null;
    }
    notifyListeners();
  }

  /// Applies new settings (time, sound, volume, repeat, on/off).
  void updateAlarm(Alarm next) {
    _alarm = next;
    if (!next.enabled) {
      if (_state != AlarmState.off) {
        _clearCycle();
        _state = AlarmState.off;
      }
      notifyListeners();
      return;
    }
    switch (_state) {
      case AlarmState.off:
      case AlarmState.missed:
      case AlarmState.armed:
        _armFromScratch();
      case AlarmState.ringing:
      case AlarmState.snoozed:
        break; // the new settings apply from the next time it is armed
    }
    notifyListeners();
  }

  // ---- Reactions to time passing ----

  /// Checks the clock. Call this about once a second.
  void tick() {
    final now = _now();
    switch (_state) {
      case AlarmState.off:
        return;
      case AlarmState.armed:
        final due = _fireAt;
        if (due == null || now.isBefore(due)) return;
        _handleDue(now, due: due, scheduledFor: due);
      case AlarmState.snoozed:
        final due = _snoozeUntil;
        if (due == null || now.isBefore(due)) return;
        _handleDue(now, due: due, scheduledFor: _scheduledFor ?? due);
      case AlarmState.ringing:
        final started = _ringStartedAt;
        if (started != null && now.difference(started) >= ringLimit) {
          _miss(scheduledFor: _scheduledFor ?? started);
        }
      case AlarmState.missed:
        // A missed daily alarm is still waiting for tomorrow.
        final due = _fireAt;
        if (!_alarm.repeatDaily || due == null || now.isBefore(due)) return;
        _handleDue(now, due: due, scheduledFor: due);
    }
  }

  /// Call when the device's clock or time zone changed, so the ring time is worked out again.
  void clockChanged() {
    final waitingForTime = _state == AlarmState.armed ||
        (_state == AlarmState.missed && _alarm.repeatDaily);
    if (!waitingForTime) return;
    _fireAt = _computeNext();
    notifyListeners();
  }

  // ---- Inside ----

  void _armFromScratch() {
    _clearCycle();
    _state = AlarmState.armed;
    _fireAt = _computeNext();
  }

  /// Forgets everything about the current ring, snooze, or missed notice.
  void _clearCycle() {
    _fireAt = null;
    _snoozeUntil = null;
    _missedAt = null;
    _ringStartedAt = null;
    _scheduledFor = null;
  }

  void _handleDue(DateTime now, {required DateTime due, required DateTime scheduledFor}) {
    if (now.difference(due) > lateLimit) {
      _miss(scheduledFor: scheduledFor);
    } else {
      _state = AlarmState.ringing;
      _ringStartedAt = now;
      _scheduledFor = scheduledFor;
      _fireAt = null;
      _snoozeUntil = null;
      _missedAt = null;
      notifyListeners();
    }
  }

  void _miss({required DateTime scheduledFor}) {
    _state = AlarmState.missed;
    _missedAt = scheduledFor;
    _snoozeUntil = null;
    _ringStartedAt = null;
    _scheduledFor = null;
    if (_alarm.repeatDaily) {
      _fireAt = _computeNext();
    } else {
      _fireAt = null;
      _alarm = _alarm.copyWith(enabled: false);
    }
    notifyListeners();
  }
}
