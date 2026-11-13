import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/weather/weather_codes.dart';

void main() {
  // Every code in the spec's table (Open-Meteo's WMO weather codes) and its icon.
  // Day and night only matter for clear and partly cloudy skies.
  const anyTime = <int, WeatherIcon>{
    3: WeatherIcon.cloudy,
    45: WeatherIcon.fog,
    48: WeatherIcon.fog,
    51: WeatherIcon.drizzle,
    53: WeatherIcon.drizzle,
    55: WeatherIcon.drizzle,
    56: WeatherIcon.sleet,
    57: WeatherIcon.sleet,
    61: WeatherIcon.rain,
    63: WeatherIcon.rain,
    65: WeatherIcon.rain,
    66: WeatherIcon.sleet,
    67: WeatherIcon.sleet,
    71: WeatherIcon.snow,
    73: WeatherIcon.snow,
    75: WeatherIcon.snow,
    77: WeatherIcon.snow,
    80: WeatherIcon.rain,
    81: WeatherIcon.rain,
    82: WeatherIcon.rain,
    85: WeatherIcon.snow,
    86: WeatherIcon.snow,
    95: WeatherIcon.thunder,
    96: WeatherIcon.thunder,
    97: WeatherIcon.thunder,
    99: WeatherIcon.thunder,
  };

  group('iconFor, codes that look the same day and night', () {
    anyTime.forEach((code, icon) {
      test('code $code is $icon', () {
        expect(iconFor(code, isDay: true), icon);
        expect(iconFor(code, isDay: false), icon);
      });
    });
  });

  group('iconFor, clear and partly cloudy', () {
    test('codes 0 and 1 are a sun by day and a moon by night', () {
      for (final code in [0, 1]) {
        expect(iconFor(code, isDay: true), WeatherIcon.clearDay);
        expect(iconFor(code, isDay: false), WeatherIcon.clearNight);
      }
    });

    test('code 2 is partly cloudy with a sun by day and a moon by night', () {
      expect(iconFor(2, isDay: true), WeatherIcon.partlyDay);
      expect(iconFor(2, isDay: false), WeatherIcon.partlyNight);
    });

    test('an unknown day/night flag is treated as day', () {
      expect(iconFor(0, isDay: null), WeatherIcon.clearDay);
      expect(iconFor(2, isDay: null), WeatherIcon.partlyDay);
    });
  });

  group('iconFor, anything else', () {
    test('unknown codes show the unavailable icon', () {
      for (final code in [-1, 4, 10, 44, 100, 1000]) {
        expect(iconFor(code, isDay: true), WeatherIcon.unavailable, reason: 'code $code');
      }
    });

    test('a missing code shows the unavailable icon', () {
      expect(iconFor(null, isDay: true), WeatherIcon.unavailable);
    });
  });

  test('there are exactly 12 icons', () {
    expect(WeatherIcon.values.length, 12);
  });
}
