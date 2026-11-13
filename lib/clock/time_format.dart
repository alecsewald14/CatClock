/// A reading on a 12-hour clock: an hour from 1 to 12, and AM or PM.
class Time12 {
  const Time12(this.hour12, this.isPm);

  /// 1 to 12. Midnight and noon are both 12.
  final int hour12;

  /// True for noon up to 11:59 PM, false for midnight up to 11:59 AM.
  final bool isPm;

  @override
  String toString() => '$hour12 ${isPm ? 'PM' : 'AM'}';
}

/// Converts an hour from 0 to 23 into a 12-hour reading.
///
/// Hour 0 is 12 AM, hour 12 is 12 PM, and hours 13 to 23 are 1 PM to 11 PM.
Time12 to12Hour(int hour24) {
  RangeError.checkValueInInterval(hour24, 0, 23, 'hour24');
  final hour = hour24 % 12;
  return Time12(hour == 0 ? 12 : hour, hour24 >= 12);
}

/// The digits shown on the clock face: no leading zero on the hour, two digits of
/// minutes. For example `7:42` or `12:05`. The AM/PM letters are shown separately.
String formatClockDigits(int hour24, int minute) {
  RangeError.checkValueInInterval(minute, 0, 59, 'minute');
  final time = to12Hour(hour24);
  return '${time.hour12}:${minute.toString().padLeft(2, '0')}';
}

/// A short label for an hour, as used above each hourly weather cell: `8PM`, `12AM`.
String hourLabel(int hour24) {
  final time = to12Hour(hour24);
  return '${time.hour12}${time.isPm ? 'PM' : 'AM'}';
}

/// A time with a space before AM or PM, as in "updated 6:15 PM".
String formatUpdated(int hour24, int minute) {
  final time = to12Hour(hour24);
  return '${formatClockDigits(hour24, minute)} ${time.isPm ? 'PM' : 'AM'}';
}
