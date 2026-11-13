import 'package:flutter/foundation.dart';

import 'alarm.dart';
import 'alarm_controller.dart';
import 'sound_catalog.dart';

/// What the screens need from "the thing that runs the alarm". Windows rings the alarm
/// itself (`AlarmService`); on the iPhone the system rings it (`IosAlarmService`).
abstract interface class AlarmEngine implements Listenable {
  Alarm get alarm;
  AlarmState get state;

  /// When a snoozed alarm rings again, if known. The iPhone does not tell the app.
  DateTime? get snoozeUntil;

  /// When a missed alarm was due. Only Windows has a "missed" state.
  DateTime? get missedAt;

  /// True if the alarm sound could not be played (Windows).
  bool get soundProblem;

  /// A plain-language problem the person should know about, or null. For example that the
  /// iPhone has alarms turned off for the app.
  String? get problem;

  /// Starts watching the clock (Windows) or the system alarm list (iPhone). Call once.
  void start();

  void setEnabled(bool enabled);
  void update(Alarm alarm);
  void stop();
  void snooze();
  void dismissMissed();

  /// Plays a short sample, for choosing a sound or checking the volume.
  Future<void> preview({AlarmSound? sound, int? level});
}
