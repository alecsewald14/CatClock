import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/weather/units.dart';

void main() {
  group('unitForRegion', () {
    test('the United States uses Fahrenheit', () {
      expect(unitForRegion('US'), TemperatureUnit.fahrenheit);
    });

    test('the region code is not case sensitive', () {
      expect(unitForRegion('us'), TemperatureUnit.fahrenheit);
      expect(unitForRegion('Us'), TemperatureUnit.fahrenheit);
    });

    test('everywhere else uses Celsius', () {
      for (final region in ['GB', 'DE', 'CA', 'MX', 'JP', 'IN', 'AU']) {
        expect(unitForRegion(region), TemperatureUnit.celsius, reason: region);
      }
    });

    test('a missing or empty region uses Celsius', () {
      expect(unitForRegion(null), TemperatureUnit.celsius);
      expect(unitForRegion(''), TemperatureUnit.celsius);
    });
  });

  group('apiValue', () {
    test('matches the words Open-Meteo expects', () {
      expect(TemperatureUnit.celsius.apiValue, 'celsius');
      expect(TemperatureUnit.fahrenheit.apiValue, 'fahrenheit');
    });
  });

  group('formatTemperature', () {
    test('rounds to a whole degree and adds the degree sign', () {
      expect(formatTemperature(54.4), '54°');
      expect(formatTemperature(54.6), '55°');
    });

    test('rounds halves upward', () {
      expect(formatTemperature(54.5), '55°');
    });

    test('keeps the minus sign for negative temperatures', () {
      expect(formatTemperature(-3.2), '-3°');
    });

    test('never shows a negative zero', () {
      expect(formatTemperature(-0.4), '0°');
      expect(formatTemperature(-0.0), '0°');
    });

    test('shows dashes when there is no value', () {
      expect(formatTemperature(null), '--°');
    });
  });
}
