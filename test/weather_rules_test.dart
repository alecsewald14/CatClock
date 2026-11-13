import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/weather/weather_rules.dart';

void main() {
  group('roundCoordinate', () {
    test('keeps 2 decimals, which is about 1 kilometre', () {
      expect(roundCoordinate(52.5249), 52.52);
      expect(roundCoordinate(13.4151), 13.42);
    });

    test('rounds negative coordinates too', () {
      expect(roundCoordinate(-33.8688), -33.87);
      expect(roundCoordinate(-122.4194), -122.42);
    });

    test('leaves already-short values alone', () {
      expect(roundCoordinate(40.7), 40.7);
      expect(roundCoordinate(0), 0);
    });

    test('never returns a negative zero', () {
      expect(roundCoordinate(-0.004).toString(), '0.0');
    });

    test('rounding loses precision, so two places a few hundred metres apart match', () {
      expect(roundCoordinate(40.7128), roundCoordinate(40.7149));
    });
  });

  group('freshnessOf', () {
    final now = DateTime.utc(2026, 11, 12, 12, 0);

    test('data fetched just now is fresh', () {
      expect(freshnessOf(now, now), WeatherFreshness.fresh);
    });

    test('data exactly 30 minutes old is still fresh', () {
      expect(
        freshnessOf(now.subtract(const Duration(minutes: 30)), now),
        WeatherFreshness.fresh,
      );
    });

    test('data a little over 30 minutes old is stale (dimmed)', () {
      expect(
        freshnessOf(now.subtract(const Duration(minutes: 30, seconds: 1)), now),
        WeatherFreshness.stale,
      );
    });

    test('data exactly 3 hours old is still stale, not unavailable', () {
      expect(
        freshnessOf(now.subtract(const Duration(hours: 3)), now),
        WeatherFreshness.stale,
      );
    });

    test('data over 3 hours old is unavailable', () {
      expect(
        freshnessOf(now.subtract(const Duration(hours: 3, seconds: 1)), now),
        WeatherFreshness.unavailable,
      );
    });

    test('no data at all is unavailable', () {
      expect(freshnessOf(null, now), WeatherFreshness.unavailable);
    });

    test('data stamped in the future (clock moved back) counts as fresh', () {
      expect(
        freshnessOf(now.add(const Duration(minutes: 5)), now),
        WeatherFreshness.fresh,
      );
    });
  });
}
