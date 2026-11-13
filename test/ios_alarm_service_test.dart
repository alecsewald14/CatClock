import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_controller.dart';
import 'package:cat_clock/alarm/alarm_store.dart';
import 'package:cat_clock/alarm/sound_catalog.dart';
import 'package:cat_clock/platform/ios/alarmkit_api.dart';
import 'package:cat_clock/platform/ios/ios_alarm_service.dart';
import 'package:cat_clock/storage/text_storage.dart';

import 'helpers/alarm_fakes.dart';
import 'helpers/alarmkit_fakes.dart';

const sixThirty = Alarm(hour: 6, minute: 30, enabled: true, soundId: 'cat_bell', volumeLevel: 4);

class Rig {
  Rig._(this.service, this.api, this.player, this.storage);

  final IosAlarmService service;
  final FakeAlarmKit api;
  final FakeSoundPlayer player;
  final MemoryTextStorage storage;

  static Future<Rig> create({
    Alarm? saved,
    FakeAlarmKit? api,
    List<SystemAlarmState> held = const [],
    bool startService = true,
  }) async {
    final fake = api ?? FakeAlarmKit(permissionState: AlarmPermission.authorized);
    fake.held = List.of(held);
    final storage = MemoryTextStorage();
    if (saved != null) await AlarmStore(storage).save(saved);
    final player = FakeSoundPlayer();
    final service = await IosAlarmService.load(api: fake, store: AlarmStore(storage), player: player);
    if (startService) service.start();
    await pumpEventQueue();
    return Rig._(service, fake, player, storage);
  }

  Future<Alarm> saved() => AlarmStore(storage).load();
}

void main() {
  group('starting', () {
    test('an alarm that is on and held by the system shows as armed, without being set again', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      expect(rig.service.state, AlarmState.armed);
      expect(rig.api.calls, isEmpty);
    });

    test('a saved one-time alarm the system no longer holds has rung, so it is switched off', () async {
      final rig = await Rig.create(saved: sixThirty);
      expect(rig.service.alarm.enabled, isFalse);
      expect(rig.service.state, AlarmState.off);
      expect((await rig.saved()).enabled, isFalse);
    });

    test('a saved daily alarm the system does not hold is set again', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(repeatDaily: true));
      expect(rig.api.scheduled.single['repeatDaily'], isTrue);
      expect(rig.service.state, AlarmState.armed);
    });

    test('a switched-off alarm is left alone', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(enabled: false));
      expect(rig.api.calls, isEmpty);
      expect(rig.service.state, AlarmState.off);
    });

    test('uses the default alarm when nothing was saved', () async {
      final rig = await Rig.create();
      expect(rig.service.alarm, const Alarm());
    });

    test('reports no missed alarm, no snooze time, and no sound problem', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      expect(rig.service.missedAt, isNull);
      expect(rig.service.snoozeUntil, isNull);
      expect(rig.service.soundProblem, isFalse);
      expect(rig.service.problem, isNull);
    });
  });

  group('turning the alarm on', () {
    test('asks for permission the first time, then sets the alarm with the chosen settings', () async {
      final api = FakeAlarmKit();
      final rig = await Rig.create(api: api, saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(api.calls, ['request', 'cancel', 'schedule']);
      expect(api.scheduled.single, {
        'hour': 6,
        'minute': 30,
        'repeatDaily': false,
        'soundFile': 'cat_bell_4.wav',
        'snoozeSeconds': 540,
      });
      expect(rig.service.state, AlarmState.armed);
      expect((await rig.saved()).enabled, isTrue);
    });

    test('does not ask again once permission was given', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.api.calls, isNot(contains('request')));
    });

    test('if the person says no, the alarm stays off and says why', () async {
      final api = FakeAlarmKit(userAllows: false);
      final rig = await Rig.create(api: api, saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.service.alarm.enabled, isFalse);
      expect(rig.service.state, AlarmState.off);
      expect(rig.service.problem, contains('Settings'));
      expect(api.scheduled, isEmpty);
      expect((await rig.saved()).enabled, isFalse);
    });

    test('permission already refused earlier: no new question, and a clear message', () async {
      final api = FakeAlarmKit(permissionState: AlarmPermission.denied);
      final rig = await Rig.create(api: api, saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(api.calls, isNot(contains('request')));
      expect(rig.service.problem, isNotNull);
    });

    test('the message goes away after a later success', () async {
      final api = FakeAlarmKit(userAllows: false);
      final rig = await Rig.create(api: api, saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      api.permissionState = AlarmPermission.authorized;
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.service.problem, isNull);
      expect(rig.service.state, AlarmState.armed);
    });

    test('a daily alarm is set to repeat', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(enabled: false, repeatDaily: true));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.api.scheduled.single['repeatDaily'], isTrue);
    });

    test('a failure to set the alarm switches it off and says so', () async {
      final api = FakeAlarmKit(permissionState: AlarmPermission.authorized)..failToSchedule = true;
      final rig = await Rig.create(api: api, saved: sixThirty.copyWith(enabled: false));
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.service.alarm.enabled, isFalse);
      expect(rig.service.problem, 'Could not set the alarm.');
    });
  });

  group('changing the settings', () {
    test('a new time replaces the system alarm: cancel, then set the new one', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.calls.clear();
      rig.service.update(sixThirty.copyWith(hour: 7, minute: 15));
      await pumpEventQueue();
      expect(rig.api.calls, ['cancel', 'schedule']);
      expect(rig.api.scheduled.last['hour'], 7);
      expect(rig.api.scheduled.last['minute'], 15);
      expect(rig.service.alarm.enabled, isTrue, reason: 'cancelling to reset is not the alarm finishing');
    });

    test('a new sound or volume changes the file the system will play', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.service.update(sixThirty.copyWith(soundId: 'purr_rise', volumeLevel: 1));
      await pumpEventQueue();
      expect(rig.api.scheduled.last['soundFile'], 'purr_rise_1.wav');
    });

    test('changing settings of an alarm that is off only saves them', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(enabled: false));
      rig.service.update(sixThirty.copyWith(enabled: false, minute: 45));
      await pumpEventQueue();
      expect(rig.api.scheduled, isEmpty);
      expect((await rig.saved()).minute, 45);
    });

    test('turning it off cancels the system alarm and saves', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.service.setEnabled(false);
      await pumpEventQueue();
      expect(rig.api.calls.last, 'cancel');
      expect(rig.service.state, AlarmState.off);
      expect((await rig.saved()).enabled, isFalse);
    });

    test('quick changes are applied in order, and the last one wins', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.service.update(sixThirty.copyWith(minute: 31));
      rig.service.update(sixThirty.copyWith(minute: 32));
      rig.service.update(sixThirty.copyWith(minute: 33));
      await pumpEventQueue();
      expect(rig.api.scheduled.map((s) => s['minute']), [31, 32, 33]);
      expect(rig.service.alarm.minute, 33);
    });

    test('the file name follows the chosen sound and level', () async {
      final rig = await Rig.create(saved: const Alarm(soundId: 'meow_melody', volumeLevel: 5));
      expect(rig.service.soundFile, 'meow_melody_5.wav');
      expect(alarmSounds.any((s) => s.id == 'meow_melody'), isTrue);
    });
  });

  group('when the alarm rings', () {
    test('shows as ringing while the system is alerting', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      expect(rig.service.state, AlarmState.ringing);
    });

    test('Stop silences it through the system', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.api.calls, contains('stop'));
    });

    test('a one-time alarm switches itself off after it has rung and been stopped', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.service.alarm.enabled, isFalse);
      expect(rig.service.state, AlarmState.off);
      expect((await rig.saved()).enabled, isFalse);
    });

    test('a daily alarm stays on after it has rung', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(repeatDaily: true), held: [SystemAlarmState.scheduled]);
      rig.api.repeating = true;
      rig.api.ring();
      await pumpEventQueue();
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.service.alarm.enabled, isTrue);
      expect(rig.service.state, AlarmState.armed);
    });

    test('Snooze shows as snoozed, and the alarm is still on', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      rig.service.snooze();
      await pumpEventQueue();
      expect(rig.service.state, AlarmState.snoozed);
      expect(rig.service.alarm.enabled, isTrue);
      expect(rig.api.calls, contains('snooze'));
    });

    test('ringing, snoozing, and ringing again does not switch the alarm off', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      rig.service.snooze();
      await pumpEventQueue();
      rig.api.ring();
      await pumpEventQueue();
      expect(rig.service.alarm.enabled, isTrue);
      expect(rig.service.state, AlarmState.ringing);
    });

    test('coming back to the app after the alarm rang while it was closed switches a one-time alarm off', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.held = []; // it rang and finished while the app was closed
      await rig.service.reconcile();
      expect(rig.service.alarm.enabled, isFalse);
    });
  });

  group('previews and cleanup', () {
    test('play a sample of the chosen sound and volume', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.service.preview();
      expect(rig.player.events, ['preview:cat_bell:4']);
    });

    test('are not played while the alarm is ringing', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.api.ring();
      await pumpEventQueue();
      await rig.service.preview();
      expect(rig.player.count('preview:'), 0);
    });

    test('starting twice does not listen twice', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      var told = 0;
      rig.service.addListener(() => told++);
      rig.service.start();
      rig.api.ring();
      await pumpEventQueue();
      expect(told, 1);
    });

    test('after dispose, system changes are ignored quietly', () async {
      final rig = await Rig.create(saved: sixThirty, held: [SystemAlarmState.scheduled]);
      rig.service.dispose();
      rig.api.ring();
      await pumpEventQueue();
    });
  });
}
