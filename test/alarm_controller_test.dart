import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_controller.dart';
import 'package:cat_clock/alarm/next_fire_time.dart';

Duration noOffset(DateTime utc) => Duration.zero;

/// US Eastern time as it is in 2026 (see next_fire_time_test.dart).
Duration eastern2026(DateTime utc) {
  final start = DateTime.utc(2026, 3, 8, 7);
  final end = DateTime.utc(2026, 11, 1, 6);
  final inDst = !utc.isBefore(start) && utc.isBefore(end);
  return Duration(hours: inDst ? -4 : -5);
}

/// A controller with a clock the test can move by hand.
class Harness {
  Harness({
    Alarm alarm = const Alarm(hour: 6, minute: 30),
    UtcOffsetAt? offsetAt,
    DateTime? start,
  }) : now = start ?? DateTime.utc(2026, 11, 11, 20, 0) {
    controller = AlarmController(
      alarm: alarm,
      nowUtc: () => now,
      offsetAt: offsetAt ?? noOffset,
    );
    controller.addListener(() => notifications++);
  }

  DateTime now;
  late final AlarmController controller;
  int notifications = 0;

  /// Moves the clock to [time] and lets the controller check it.
  void at(DateTime time) {
    now = time;
    controller.tick();
  }
}

// With the default harness (UTC, start 2026-11-11 20:00), a 6:30 alarm rings here.
final fire = DateTime.utc(2026, 11, 12, 6, 30);
final nextDayFire = DateTime.utc(2026, 11, 13, 6, 30);

void main() {
  group('starting up', () {
    test('starts off when the saved alarm is off', () {
      final h = Harness();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.fireAt, isNull);
    });

    test('starts armed when the saved alarm is on', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.fireAt, fire);
    });

    test('ticking while off changes nothing', () {
      final h = Harness();
      h.at(DateTime.utc(2026, 11, 12, 7));
      expect(h.controller.state, AlarmState.off);
      expect(h.notifications, 0);
    });
  });

  group('arming', () {
    test('arm turns the alarm on and works out when it rings', () {
      final h = Harness();
      h.controller.arm();
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.alarm.enabled, isTrue);
      expect(h.controller.fireAt, fire);
    });

    test('stays armed until the moment arrives', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire.subtract(const Duration(seconds: 1)));
      expect(h.controller.state, AlarmState.armed);
    });

    test('rings at the moment it arrives', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      expect(h.controller.state, AlarmState.ringing);
    });

    test('arm does nothing while the alarm is ringing', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      final before = h.notifications;
      h.controller.arm();
      expect(h.controller.state, AlarmState.ringing);
      expect(h.notifications, before);
    });

    test('disarm turns an armed alarm fully off', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.controller.disarm();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.alarm.enabled, isFalse);
      expect(h.controller.fireAt, isNull);
    });

    test('disarm stops a ringing alarm for good, even with daily repeat', () {
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
      );
      h.at(fire);
      h.controller.disarm();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.alarm.enabled, isFalse);
      expect(h.controller.alarm.repeatDaily, isTrue, reason: 'the switch stays as set');
    });

    test('disarm also cancels a snooze', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.controller.snooze();
      h.controller.disarm();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.snoozeUntil, isNull);
    });
  });

  group('waking late', () {
    test('rings right away when the laptop wakes within 10 minutes after', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire.add(const Duration(minutes: 9, seconds: 59)));
      expect(h.controller.state, AlarmState.ringing);
    });

    test('exactly 10 minutes late still rings', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire.add(const Duration(minutes: 10)));
      expect(h.controller.state, AlarmState.ringing);
    });

    test('more than 10 minutes late is a missed alarm', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire.add(const Duration(minutes: 10, milliseconds: 1)));
      expect(h.controller.state, AlarmState.missed);
      expect(h.controller.missedAt, fire);
      expect(h.controller.alarm.enabled, isFalse);
      expect(h.controller.fireAt, isNull);
    });
  });

  group('stopping', () {
    test('stop turns a one-time alarm off', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.controller.stop();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.alarm.enabled, isFalse);
    });

    test('stop re-arms a daily alarm for the same time tomorrow', () {
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
      );
      h.at(fire);
      h.controller.stop();
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.alarm.enabled, isTrue);
      expect(h.controller.fireAt, nextDayFire);
    });

    test('stop does nothing when the alarm is not ringing', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.controller.stop();
      expect(h.controller.state, AlarmState.armed);
    });
  });

  group('snooze', () {
    test('snooze waits 9 minutes and then rings again', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      final ringTime = fire.add(const Duration(seconds: 5));
      h.at(ringTime);
      expect(h.controller.state, AlarmState.ringing);

      h.controller.snooze();
      expect(h.controller.state, AlarmState.snoozed);
      final wakeUp = ringTime.add(const Duration(minutes: 9));
      expect(h.controller.snoozeUntil, wakeUp);

      h.at(wakeUp.subtract(const Duration(seconds: 1)));
      expect(h.controller.state, AlarmState.snoozed);

      h.at(wakeUp);
      expect(h.controller.state, AlarmState.ringing);
      expect(h.controller.snoozeUntil, isNull);
    });

    test('snooze can be used again on the second ring', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.controller.snooze();
      h.at(fire.add(const Duration(minutes: 9)));
      h.controller.snooze();
      expect(h.controller.state, AlarmState.snoozed);
      expect(h.controller.snoozeUntil, fire.add(const Duration(minutes: 18)));
    });

    test('stop during a snooze ends the alarm', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.controller.snooze();
      h.controller.stop();
      expect(h.controller.state, AlarmState.off);
    });

    test('stop during a snooze on a daily alarm re-arms it for tomorrow', () {
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
      );
      h.at(fire);
      h.controller.snooze();
      h.controller.stop();
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.fireAt, nextDayFire);
    });

    test('snooze does nothing unless the alarm is ringing', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.controller.snooze();
      expect(h.controller.state, AlarmState.armed);
    });

    test('a snooze slept through for more than 10 minutes is missed', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.controller.snooze();
      final wakeUp = fire.add(const Duration(minutes: 9));
      h.at(wakeUp.add(const Duration(minutes: 10, milliseconds: 1)));
      expect(h.controller.state, AlarmState.missed);
      expect(h.controller.missedAt, fire, reason: 'reports the original alarm time');
    });
  });

  group('no response', () {
    test('keeps ringing for just under 10 minutes', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 9, seconds: 59)));
      expect(h.controller.state, AlarmState.ringing);
    });

    test('becomes missed after 10 minutes of ringing', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 10)));
      expect(h.controller.state, AlarmState.missed);
      expect(h.controller.missedAt, fire);
      expect(h.controller.alarm.enabled, isFalse);
    });

    test('a missed daily alarm stays armed for tomorrow and rings then', () {
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
      );
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 10)));
      expect(h.controller.state, AlarmState.missed);
      expect(h.controller.alarm.enabled, isTrue);
      expect(h.controller.fireAt, nextDayFire);
      expect(h.controller.missedAt, fire);

      h.at(nextDayFire);
      expect(h.controller.state, AlarmState.ringing);
      expect(h.controller.missedAt, isNull);
    });

    test('dismissing a missed one-time alarm leaves it off', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 10)));
      h.controller.dismissMissed();
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.missedAt, isNull);
    });

    test('dismissing a missed daily alarm leaves it armed', () {
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
      );
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 10)));
      h.controller.dismissMissed();
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.fireAt, nextDayFire);
      expect(h.controller.missedAt, isNull);
    });

    test('turning a missed alarm back on arms it again', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.at(fire);
      h.at(fire.add(const Duration(minutes: 10)));
      h.controller.arm();
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.missedAt, isNull);
      expect(h.controller.fireAt, nextDayFire);
    });
  });

  group('changing the alarm while it is armed', () {
    test('a new time moves the ring time', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.controller.updateAlarm(h.controller.alarm.copyWith(hour: 7, minute: 0));
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.fireAt, DateTime.utc(2026, 11, 12, 7, 0));
    });

    test('turning enabled off through an update turns the alarm off', () {
      final h = Harness(alarm: const Alarm(hour: 6, minute: 30, enabled: true));
      h.controller.updateAlarm(h.controller.alarm.copyWith(enabled: false));
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.fireAt, isNull);
    });

    test('turning enabled on through an update arms the alarm', () {
      final h = Harness();
      h.controller.updateAlarm(h.controller.alarm.copyWith(enabled: true));
      expect(h.controller.state, AlarmState.armed);
      expect(h.controller.fireAt, fire);
    });

    test('changing only the sound while off keeps it off', () {
      final h = Harness();
      h.controller.updateAlarm(h.controller.alarm.copyWith(soundId: 'cat_bell'));
      expect(h.controller.state, AlarmState.off);
      expect(h.controller.alarm.soundId, 'cat_bell');
    });
  });

  group('clock changes', () {
    test('a time zone change moves the ring time', () {
      var offset = Duration.zero;
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true),
        offsetAt: (utc) => offset,
      );
      expect(h.controller.fireAt, fire);

      // The laptop moves one hour east: 6:30 AM there is 05:30 UTC.
      offset = const Duration(hours: 1);
      h.controller.clockChanged();
      expect(h.controller.fireAt, DateTime.utc(2026, 11, 12, 5, 30));
    });

    test('clockChanged leaves a snooze alone', () {
      var offset = Duration.zero;
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true),
        offsetAt: (utc) => offset,
      );
      h.at(fire);
      h.controller.snooze();
      final until = h.controller.snoozeUntil;
      offset = const Duration(hours: 3);
      h.controller.clockChanged();
      expect(h.controller.snoozeUntil, until);
      expect(h.controller.state, AlarmState.snoozed);
    });
  });

  group('daylight saving', () {
    test('a daily alarm keeps its wall-clock time across spring-forward', () {
      // 7:00 PM in New York on 2026-03-06.
      final h = Harness(
        alarm: const Alarm(hour: 6, minute: 30, enabled: true, repeatDaily: true),
        offsetAt: eastern2026,
        start: DateTime.utc(2026, 3, 7, 0, 0),
      );
      // 6:30 AM on 2026-03-07 is still standard time: 11:30 UTC.
      expect(h.controller.fireAt, DateTime.utc(2026, 3, 7, 11, 30));

      h.at(DateTime.utc(2026, 3, 7, 11, 30));
      expect(h.controller.state, AlarmState.ringing);
      h.controller.stop();

      // The next morning clocks have jumped forward: 6:30 AM is 10:30 UTC, an hour earlier.
      expect(h.controller.fireAt, DateTime.utc(2026, 3, 8, 10, 30));
    });
  });

  group('listeners', () {
    test('are told about each change but not about quiet ticks', () {
      final h = Harness();
      h.controller.arm();
      expect(h.notifications, 1);

      h.at(fire.subtract(const Duration(minutes: 1)));
      expect(h.notifications, 1, reason: 'nothing changed');

      h.at(fire);
      expect(h.notifications, 2, reason: 'started ringing');

      h.at(fire.add(const Duration(seconds: 1)));
      expect(h.notifications, 2, reason: 'still ringing');

      h.controller.stop();
      expect(h.notifications, 3);
    });
  });
}
