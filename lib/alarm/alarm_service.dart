import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm.dart';
import 'alarm_controller.dart';
import 'alarm_store.dart';
import 'next_fire_time.dart';
import 'second_ticker.dart';
import 'sound_catalog.dart';
import 'sound_player.dart';

/// Runs the alarm on Windows: checks the clock every second, plays the sound while it
/// rings, and saves the settings.
///
/// The rules of when the alarm rings, snoozes, and is missed live in [AlarmController];
/// this class connects them to the clock, the speakers, and the saved file.
class AlarmService extends ChangeNotifier {
  AlarmService({
    required this.controller,
    required this._store,
    required this._player,
    required this._ticker,
    required this._nowUtc,
    required this._offsetAt,
    this.onRing,
  });

  /// Reads the saved alarm and builds a service around it.
  static Future<AlarmService> load({
    required AlarmStore store,
    required SoundPlayer player,
    required SecondTicker ticker,
    required DateTime Function() nowUtc,
    required UtcOffsetAt offsetAt,
    void Function()? onRing,
  }) async {
    final saved = await store.load();
    final controller = AlarmController(alarm: saved, nowUtc: nowUtc, offsetAt: offsetAt);
    return AlarmService(
      controller: controller,
      store: store,
      player: player,
      ticker: ticker,
      nowUtc: nowUtc,
      offsetAt: offsetAt,
      onRing: onRing,
    );
  }

  /// The rules and the current state of the alarm.
  final AlarmController controller;

  /// Called once each time the alarm starts ringing, so the app can bring its window forward.
  void Function()? onRing;

  final AlarmStore _store;
  final SoundPlayer _player;
  final SecondTicker _ticker;
  final DateTime Function() _nowUtc;
  final UtcOffsetAt _offsetAt;

  Alarm? _lastSaved;
  bool _soundOn = false;
  bool _soundProblem = false;
  bool _started = false;
  bool _disposed = false;
  Duration? _lastOffset;

  /// True if the alarm sound could not be played. The alarm still shows as ringing.
  bool get soundProblem => _soundProblem;

  Alarm get alarm => controller.alarm;
  AlarmState get state => controller.state;
  DateTime? get fireAt => controller.fireAt;
  DateTime? get snoozeUntil => controller.snoozeUntil;
  DateTime? get missedAt => controller.missedAt;

  /// Starts checking the clock. Call once.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _lastSaved = controller.alarm;
    _lastOffset = _offsetAt(_nowUtc());
    controller.addListener(_onControllerChanged);
    _ticker.start(_onTick);
    _syncSound();
  }

  // ---- Commands from the person ----

  /// Turns the alarm on or off.
  void setEnabled(bool enabled) {
    if (enabled) {
      controller.arm();
    } else {
      controller.disarm();
    }
  }

  /// Applies new settings (time, sound, volume, repeat).
  void update(Alarm alarm) => controller.updateAlarm(alarm);

  void stop() => controller.stop();
  void snooze() => controller.snooze();
  void dismissMissed() => controller.dismissMissed();

  /// Plays a short sample of the current sound at the current volume. Does nothing while
  /// the alarm is ringing, so the two never talk over each other.
  Future<void> preview({AlarmSound? sound, int? level}) async {
    if (controller.state == AlarmState.ringing) return;
    try {
      await _player.playPreview(sound ?? soundById(alarm.soundId), level ?? alarm.volumeLevel);
    } catch (_) {
      // A preview that cannot play is not worth interrupting anything for.
    }
  }

  // ---- Inside ----

  void _onTick() {
    final now = _nowUtc();

    // A change of time zone, or of daylight saving, moves the ring time. A long gap
    // between ticks, as after sleep, must NOT: the alarm that came due while the laptop
    // slept has to ring (or be marked missed), not be pushed on to tomorrow.
    final offset = _offsetAt(now);
    if (offset != _lastOffset) {
      controller.clockChanged();
    }
    _lastOffset = offset;

    controller.tick();
  }

  void _onControllerChanged() {
    _syncSound();
    final current = controller.alarm;
    if (current != _lastSaved) {
      _lastSaved = current;
      unawaited(_save(current));
    }
    notifyListeners();
  }

  Future<void> _save(Alarm alarm) async {
    try {
      await _store.save(alarm);
    } catch (_) {
      // The alarm keeps working for this run even if it could not be saved.
    }
  }

  void _syncSound() {
    final ringing = controller.state == AlarmState.ringing;
    if (ringing && !_soundOn) {
      _soundOn = true;
      unawaited(_startSound());
      onRing?.call();
    } else if (!ringing && _soundOn) {
      _soundOn = false;
      unawaited(_stopSound());
    }
  }

  Future<void> _startSound() async {
    try {
      await _player.playAlarm(soundById(alarm.soundId), alarm.volumeLevel);
      if (_soundProblem && !_disposed) {
        _soundProblem = false;
        notifyListeners();
      }
    } catch (_) {
      if (_disposed) return;
      _soundProblem = true;
      notifyListeners();
    }
  }

  Future<void> _stopSound() async {
    try {
      await _player.stop();
    } catch (_) {
      // Nothing more can be done about a player that will not stop.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.stop();
    controller.removeListener(_onControllerChanged);
    unawaited(_stopSound());
    controller.dispose();
    super.dispose();
  }
}
