import 'dart:async';

import 'package:flutter/services.dart';

/// Whether the person has allowed the app to set alarms.
enum AlarmPermission { notDetermined, authorized, denied }

/// What an alarm the system holds is doing.
enum SystemAlarmState { scheduled, countdown, paused, alerting }

/// The channel names, shared with ios/Runner/AlarmBridge.swift. A test checks they match.
const String alarmKitChannelName = 'app.catclock/alarmkit';
const String alarmKitEventsName = 'app.catclock/alarmkit/events';

/// Apple's alarm service (AlarmKit, iOS 26 and later), as the app sees it.
abstract interface class AlarmKitApi {
  Future<AlarmPermission> permission();

  /// Shows the system's permission question the first time.
  Future<AlarmPermission> requestPermission();

  /// Sets the one alarm. [soundFile] is a file inside the app, such as `cat_bell_3.wav`.
  Future<void> schedule({
    required int hour,
    required int minute,
    required bool repeatDaily,
    required String soundFile,
    required int snoozeSeconds,
  });

  /// Removes every alarm this app has set.
  Future<void> cancelAll();

  /// Silences an alarm that is ringing.
  Future<void> stopAll();

  /// Snoozes an alarm that is ringing.
  Future<void> snoozeAll();

  /// The alarms the system holds right now.
  Future<List<SystemAlarmState>> current();

  /// The list of alarms the system holds, each time it changes.
  Stream<List<SystemAlarmState>> get updates;
}

SystemAlarmState _stateFromName(Object? name) {
  return SystemAlarmState.values.firstWhere(
    (s) => s.name == name,
    orElse: () => SystemAlarmState.scheduled,
  );
}

AlarmPermission _permissionFromName(Object? name) {
  return AlarmPermission.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AlarmPermission.notDetermined,
  );
}

/// Talks to AlarmKit through the Swift code in the iPhone app.
class MethodChannelAlarmKit implements AlarmKitApi {
  MethodChannelAlarmKit({
    this._channel = const MethodChannel(alarmKitChannelName),
    this._events = const EventChannel(alarmKitEventsName),
  });

  final MethodChannel _channel;
  final EventChannel _events;

  @override
  Future<AlarmPermission> permission() async =>
      _permissionFromName(await _channel.invokeMethod<String>('permission'));

  @override
  Future<AlarmPermission> requestPermission() async =>
      _permissionFromName(await _channel.invokeMethod<String>('requestPermission'));

  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required bool repeatDaily,
    required String soundFile,
    required int snoozeSeconds,
  }) {
    return _channel.invokeMethod<void>('schedule', <String, Object>{
      'hour': hour,
      'minute': minute,
      'repeatDaily': repeatDaily,
      'soundFile': soundFile,
      'snoozeSeconds': snoozeSeconds,
    });
  }

  @override
  Future<void> cancelAll() => _channel.invokeMethod<void>('cancelAll');

  @override
  Future<void> stopAll() => _channel.invokeMethod<void>('stopAll');

  @override
  Future<void> snoozeAll() => _channel.invokeMethod<void>('snoozeAll');

  @override
  Future<List<SystemAlarmState>> current() async {
    final names = await _channel.invokeListMethod<String>('current') ?? const <String>[];
    return [for (final name in names) _stateFromName(name)];
  }

  @override
  Stream<List<SystemAlarmState>> get updates {
    return _events.receiveBroadcastStream().map((event) {
      final names = (event as List<Object?>?) ?? const <Object?>[];
      return [for (final name in names) _stateFromName(name)];
    });
  }
}
