/// Tells how far a time zone is ahead of UTC at a given moment.
///
/// A zone is passed in as a function so that the alarm logic can be tested with any
/// zone, including ones with daylight saving, on any laptop.
typedef UtcOffsetAt = Duration Function(DateTime utcInstant);

/// The offset the device's own time zone has at [utcInstant].
Duration systemUtcOffsetAt(DateTime utcInstant) => utcInstant.toLocal().timeZoneOffset;

/// The next moment, strictly after [nowUtc], when the wall clock reads [hour]:[minute].
///
/// All times are UTC instants. [offsetAt] says what the local offset is at any instant.
///
/// Daylight saving rules, which are also tested:
/// * A time that does not exist on a day (clocks jump forward over it) rings at the
///   first valid moment after it.
/// * A time that happens twice (clocks fall back) rings the first time only. Once that
///   has passed, the next ring is the following day, never the second pass.
DateTime nextFireTime({
  required DateTime nowUtc,
  required int hour,
  required int minute,
  required UtcOffsetAt offsetAt,
}) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(nowUtc, 'nowUtc', 'must be a UTC time');
  }
  RangeError.checkValueInInterval(hour, 0, 23, 'hour');
  RangeError.checkValueInInterval(minute, 0, 59, 'minute');

  // The local calendar date it is right now, written as a UTC date for easy arithmetic.
  final nowWall = nowUtc.add(offsetAt(nowUtc));
  var day = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);

  // Today's ring time is used if it is still ahead. Otherwise tomorrow's is.
  for (var i = 0; i < 3; i++) {
    final wall = DateTime.utc(day.year, day.month, day.day, hour, minute);
    final instant = firstInstantAtWall(wall, offsetAt);
    if (instant.isAfter(nowUtc)) return instant;
    day = day.add(const Duration(days: 1));
  }
  throw StateError('Could not find the next ring time for $hour:$minute');
}

/// Turns a wall-clock reading into the instant it happens.
///
/// [wallAsUtc] holds the year, month, day, hour and minute shown on the wall clock,
/// written as if they were UTC. If the reading happens twice, the earlier instant is
/// returned. If it never happens (skipped by a clock change), the first instant whose
/// wall clock is at or after it is returned.
DateTime firstInstantAtWall(DateTime wallAsUtc, UtcOffsetAt offsetAt) {
  final before = offsetAt(wallAsUtc.subtract(const Duration(days: 1)));
  final after = offsetAt(wallAsUtc.add(const Duration(days: 1)));

  DateTime? earliest;
  for (final offset in {before, after}) {
    final candidate = wallAsUtc.subtract(offset);
    if (offsetAt(candidate) == offset &&
        (earliest == null || candidate.isBefore(earliest))) {
      earliest = candidate;
    }
  }
  if (earliest != null) return earliest;

  // Nothing matches, so clocks jumped over this reading. If the offset grew, the instant
  // just before the jump and the instant just after it surround the answer. Search
  // between them, a minute at a time, for the first instant at or past the wall time.
  if (!(after > before)) return wallAsUtc.subtract(before);

  const msPerMinute = 60 * 1000;
  final wallMs = wallAsUtc.millisecondsSinceEpoch;

  int wallAtMinute(int minute) {
    final instant = DateTime.fromMillisecondsSinceEpoch(minute * msPerMinute, isUtc: true);
    return minute * msPerMinute + offsetAt(instant).inMilliseconds;
  }

  var low = wallAsUtc.subtract(after).millisecondsSinceEpoch ~/ msPerMinute;
  var high = wallAsUtc.subtract(before).millisecondsSinceEpoch ~/ msPerMinute;
  // Invariant: the wall clock is before the reading at `low`, and at or past it at `high`.
  while (high - low > 1) {
    final middle = low + (high - low) ~/ 2;
    if (wallAtMinute(middle) >= wallMs) {
      high = middle;
    } else {
      low = middle;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(high * msPerMinute, isUtc: true);
}
