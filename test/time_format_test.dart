import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/clock/time_format.dart';

void main() {
  group('to12Hour', () {
    test('midnight (hour 0) is 12 AM', () {
      final t = to12Hour(0);
      expect(t.hour12, 12);
      expect(t.isPm, isFalse);
    });

    test('1 AM and 11 AM stay in the morning', () {
      expect(to12Hour(1).hour12, 1);
      expect(to12Hour(1).isPm, isFalse);
      expect(to12Hour(11).hour12, 11);
      expect(to12Hour(11).isPm, isFalse);
    });

    test('noon (hour 12) is 12 PM', () {
      final t = to12Hour(12);
      expect(t.hour12, 12);
      expect(t.isPm, isTrue);
    });

    test('13 to 23 are 1 PM to 11 PM', () {
      for (var h = 13; h <= 23; h++) {
        final t = to12Hour(h);
        expect(t.hour12, h - 12, reason: 'hour $h');
        expect(t.isPm, isTrue, reason: 'hour $h');
      }
    });

    test('rejects hours outside 0 to 23', () {
      expect(() => to12Hour(-1), throwsRangeError);
      expect(() => to12Hour(24), throwsRangeError);
    });
  });

  group('formatClockDigits', () {
    test('has no leading zero on the hour', () {
      expect(formatClockDigits(7, 42), '7:42');
      expect(formatClockDigits(1, 5), '1:05');
    });

    test('shows 12 for midnight and noon', () {
      expect(formatClockDigits(0, 5), '12:05');
      expect(formatClockDigits(12, 0), '12:00');
    });

    test('handles the last minute of the day', () {
      expect(formatClockDigits(23, 59), '11:59');
    });

    test('always pads minutes to two digits', () {
      expect(formatClockDigits(9, 0), '9:00');
      expect(formatClockDigits(9, 9), '9:09');
    });

    test('rejects invalid minutes', () {
      expect(() => formatClockDigits(7, -1), throwsRangeError);
      expect(() => formatClockDigits(7, 60), throwsRangeError);
    });
  });

  group('hourLabel', () {
    test('labels afternoon and evening hours', () {
      expect(hourLabel(20), '8PM');
      expect(hourLabel(13), '1PM');
    });

    test('labels morning hours', () {
      expect(hourLabel(9), '9AM');
      expect(hourLabel(1), '1AM');
    });

    test('labels midnight and noon', () {
      expect(hourLabel(0), '12AM');
      expect(hourLabel(12), '12PM');
    });
  });

  group('formatUpdated', () {
    test('writes a time with a space before AM or PM', () {
      expect(formatUpdated(18, 15), '6:15 PM');
      expect(formatUpdated(0, 0), '12:00 AM');
      expect(formatUpdated(12, 5), '12:05 PM');
    });
  });
}
