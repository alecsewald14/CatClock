import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/next_fire_time.dart';

/// US Eastern time as it is in 2026, so daylight saving changes can be tested on any
/// laptop whatever its own time zone is.
/// Clocks jump forward on 2026-03-08 at 2:00 AM (07:00 UTC) and back on 2026-11-01 at
/// 2:00 AM daylight time (06:00 UTC).
Duration eastern2026(DateTime utc) {
  final start = DateTime.utc(2026, 3, 8, 7);
  final end = DateTime.utc(2026, 11, 1, 6);
  final inDst = !utc.isBefore(start) && utc.isBefore(end);
  return Duration(hours: inDst ? -4 : -5);
}

Duration noOffset(DateTime utc) => Duration.zero;

/// India has no daylight saving and an offset that is not a whole number of hours.
Duration india(DateTime utc) => const Duration(hours: 5, minutes: 30);

void main() {
  group('nextFireTime, ordinary days', () {
    test('rings later today when the time has not come yet', () {
      // 10:00 AM in New York on 2026-11-11, alarm for 6:30 PM.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 11, 15, 0),
        hour: 18,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 11, 23, 30));
    });

    test('rings tomorrow when today\'s time has already passed', () {
      // 7:00 PM in New York on 2026-11-11, alarm for 6:30 AM.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 12, 0, 0),
        hour: 6,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 12, 11, 30));
    });

    test('exactly at the alarm minute means tomorrow (strictly after now)', () {
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 11, 11, 30),
        hour: 6,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 12, 11, 30));
    });

    test('one millisecond before the alarm still means today', () {
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 11, 11, 29, 59, 999),
        hour: 6,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 11, 11, 30));
    });

    test('a midnight alarm at 11:59 PM rings one minute later', () {
      // 11:59 PM in New York on 2026-11-11.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 12, 4, 59),
        hour: 0,
        minute: 0,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 12, 5, 0));
    });

    test('works in a zone with a half-hour offset', () {
      // 05:30 in India at 00:00 UTC; alarm for 6:00 rings half an hour later.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 11, 0, 0),
        hour: 6,
        minute: 0,
        offsetAt: india,
      );
      expect(result, DateTime.utc(2026, 11, 11, 0, 30));
    });

    test('works with no offset', () {
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 11, 20, 0),
        hour: 6,
        minute: 30,
        offsetAt: noOffset,
      );
      expect(result, DateTime.utc(2026, 11, 12, 6, 30));
    });
  });

  group('nextFireTime, clock changes', () {
    test('keeps the same wall-clock time across the spring-forward change', () {
      // 8:00 PM in New York on 2026-03-07; the alarm is for 6:30 AM the next morning,
      // after clocks have jumped forward, so it is 10:30 UTC, not 11:30 UTC.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 3, 8, 1, 0),
        hour: 6,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 3, 8, 10, 30));
    });

    test('a time skipped by spring-forward rings at the first valid moment', () {
      // 1:00 AM in New York on 2026-03-08. 2:30 AM does not exist that day, so the alarm
      // rings at 3:00 AM daylight time, which is 07:00 UTC.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 3, 8, 6, 0),
        hour: 2,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 3, 8, 7, 0));
    });

    test('a time repeated by fall-back rings the first time', () {
      // Midnight in New York on 2026-11-01. 1:30 AM happens twice; the first is 05:30 UTC.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 1, 4, 0),
        hour: 1,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 1, 5, 30));
    });

    test('after the first pass of a repeated hour, the next ring is tomorrow', () {
      // 05:45 UTC is after the first 1:30 AM and before the second. The alarm must not
      // ring at the second 1:30 AM (06:30 UTC); it waits for 1:30 AM the next day.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 1, 5, 45),
        hour: 1,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 2, 6, 30));
    });

    test('a time outside the repeated hour uses the new offset on fall-back day', () {
      // 6:30 AM on 2026-11-01 is after the change, so it is 11:30 UTC.
      final result = nextFireTime(
        nowUtc: DateTime.utc(2026, 11, 1, 4, 0),
        hour: 6,
        minute: 30,
        offsetAt: eastern2026,
      );
      expect(result, DateTime.utc(2026, 11, 1, 11, 30));
    });
  });

  group('nextFireTime, bad input', () {
    test('rejects an hour outside 0 to 23', () {
      expect(
        () => nextFireTime(
          nowUtc: DateTime.utc(2026, 11, 11),
          hour: 24,
          minute: 0,
          offsetAt: noOffset,
        ),
        throwsRangeError,
      );
    });

    test('rejects a minute outside 0 to 59', () {
      expect(
        () => nextFireTime(
          nowUtc: DateTime.utc(2026, 11, 11),
          hour: 6,
          minute: 60,
          offsetAt: noOffset,
        ),
        throwsRangeError,
      );
    });

    test('rejects a "now" that is not in UTC', () {
      expect(
        () => nextFireTime(
          nowUtc: DateTime(2026, 11, 11, 12),
          hour: 6,
          minute: 0,
          offsetAt: noOffset,
        ),
        throwsArgumentError,
      );
    });
  });

  group('systemUtcOffsetAt', () {
    test('returns an offset that is consistent with Dart\'s own local time', () {
      final instant = DateTime.utc(2026, 7, 1, 12);
      expect(systemUtcOffsetAt(instant), instant.toLocal().timeZoneOffset);
    });
  });
}
