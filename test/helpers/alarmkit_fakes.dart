import 'dart:async';

import 'package:cat_clock/platform/ios/alarmkit_api.dart';
import 'package:cat_clock/platform/signature_info.dart';

/// Pretends to be Apple's alarm service, and writes down what it was asked.
class FakeAlarmKit implements AlarmKitApi {
  FakeAlarmKit({this.permissionState = AlarmPermission.notDetermined, this.userAllows = true});

  AlarmPermission permissionState;
  bool userAllows;
  bool failToSchedule = false;
  List<SystemAlarmState> held = [];
  final List<String> calls = [];
  final List<Map<String, Object>> scheduled = [];
  final _controller = StreamController<List<SystemAlarmState>>.broadcast();

  void _emit() => _controller.add(List.of(held));

  @override
  Future<AlarmPermission> permission() async => permissionState;

  @override
  Future<AlarmPermission> requestPermission() async {
    calls.add('request');
    permissionState = userAllows ? AlarmPermission.authorized : AlarmPermission.denied;
    return permissionState;
  }

  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required bool repeatDaily,
    required String soundFile,
    required int snoozeSeconds,
  }) async {
    calls.add('schedule');
    if (failToSchedule) throw StateError('no');
    scheduled.add({
      'hour': hour,
      'minute': minute,
      'repeatDaily': repeatDaily,
      'soundFile': soundFile,
      'snoozeSeconds': snoozeSeconds,
    });
    held = [SystemAlarmState.scheduled];
    _emit();
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancel');
    held = [];
    _emit();
  }

  @override
  Future<void> stopAll() async {
    calls.add('stop');
    // A one-time alarm disappears once stopped; a repeating one waits for tomorrow.
    held = repeating ? [SystemAlarmState.scheduled] : [];
    _emit();
  }

  @override
  Future<void> snoozeAll() async {
    calls.add('snooze');
    held = [SystemAlarmState.countdown];
    _emit();
  }

  @override
  Future<List<SystemAlarmState>> current() async => List.of(held);

  @override
  Stream<List<SystemAlarmState>> get updates => _controller.stream;

  bool repeating = false;

  /// The alarm time arrives and the system rings.
  void ring() {
    held = [SystemAlarmState.alerting];
    _emit();
  }
}

/// Says a fixed signature expiry, and counts how often it was asked.
class FakeSignatureInfo implements SignatureInfo {
  FakeSignatureInfo(this.expires);

  DateTime? expires;
  int asked = 0;

  @override
  Future<DateTime?> expiresAt() async {
    asked++;
    return expires;
  }
}
