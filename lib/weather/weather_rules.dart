/// How trustworthy the last weather result is.
enum WeatherFreshness {
  /// Recent enough to show normally.
  fresh,

  /// Older than 30 minutes: still shown, but dimmed with "updated 6:15 PM".
  stale,

  /// Older than 3 hours, or missing: every weather cell shows the "unavailable" picture.
  unavailable,
}

/// Rounds a latitude or longitude to 2 decimals, which is about 1 kilometre. This is all
/// the precision that is ever sent to the weather service.
double roundCoordinate(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  // Avoid "-0.0" for tiny negative numbers.
  return rounded == 0 ? 0.0 : rounded;
}

/// Judges how old the weather is. Data stamped in the future (the clock was moved back)
/// counts as fresh.
WeatherFreshness freshnessOf(
  DateTime? fetchedAtUtc,
  DateTime nowUtc, {
  Duration staleAfter = const Duration(minutes: 30),
  Duration unavailableAfter = const Duration(hours: 3),
}) {
  if (fetchedAtUtc == null) return WeatherFreshness.unavailable;
  final age = nowUtc.difference(fetchedAtUtc);
  if (age > unavailableAfter) return WeatherFreshness.unavailable;
  if (age > staleAfter) return WeatherFreshness.stale;
  return WeatherFreshness.fresh;
}
