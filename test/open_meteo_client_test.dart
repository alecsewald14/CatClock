import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/weather/open_meteo_client.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_models.dart';

/// A small hand-made response with the same shape as the real one.
Map<String, dynamic> fakeResponse({
  String currentTime = '2026-11-12T10:20',
  List<String>? times,
  List<Object?>? temps,
  List<Object?>? codes,
  List<Object?>? days,
  Object? currentTemp = 50.0,
  Object? currentCode = 3,
  Object? currentIsDay = 1,
}) {
  times ??= [
    '2026-11-12T10:00',
    '2026-11-12T11:00',
    '2026-11-12T12:00',
    '2026-11-12T13:00',
    '2026-11-12T14:00',
    '2026-11-12T15:00',
    '2026-11-12T16:00',
  ];
  temps ??= [50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0];
  codes ??= [3, 3, 61, 61, 63, 2, 0];
  days ??= [1, 1, 1, 1, 1, 1, 0];
  return {
    'current': {
      'time': currentTime,
      'temperature_2m': currentTemp,
      'weather_code': currentCode,
      'is_day': currentIsDay,
    },
    'hourly': {
      'time': times,
      'temperature_2m': temps,
      'weather_code': codes,
      'is_day': days,
    },
  };
}

WeatherSnapshot parse(
  Map<String, dynamic> json, {
  TemperatureUnit unit = TemperatureUnit.fahrenheit,
}) {
  return parseForecast(
    json,
    fetchedAtUtc: DateTime.utc(2026, 11, 12, 15, 20),
    latitude: 52.52,
    longitude: 13.41,
    unit: unit,
  );
}

void main() {
  group('buildForecastUri', () {
    test('asks Open-Meteo for the fields and hours in the spec', () {
      final uri = buildForecastUri(
        latitude: 52.52,
        longitude: 13.41,
        unit: TemperatureUnit.fahrenheit,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.open-meteo.com');
      expect(uri.path, '/v1/forecast');
      expect(uri.queryParameters, {
        'latitude': '52.52',
        'longitude': '13.41',
        'current': 'temperature_2m,weather_code,is_day',
        'hourly': 'temperature_2m,weather_code,is_day',
        'forecast_hours': '7',
        'temperature_unit': 'fahrenheit',
        'timezone': 'auto',
      });
    });

    test('rounds coordinates to 2 decimals before they leave the device', () {
      final uri = buildForecastUri(
        latitude: 40.712776,
        longitude: -74.005974,
        unit: TemperatureUnit.celsius,
      );
      expect(uri.queryParameters['latitude'], '40.71');
      expect(uri.queryParameters['longitude'], '-74.01');
      expect(uri.queryParameters['temperature_unit'], 'celsius');
    });

    test('never puts more than 2 decimals in the address', () {
      final uri = buildForecastUri(
        latitude: 1.23456789,
        longitude: 9.87654321,
        unit: TemperatureUnit.celsius,
      );
      expect(uri.toString(), isNot(contains('1.2345')));
      expect(uri.toString(), isNot(contains('9.8765')));
    });
  });

  group('parseForecast with a real saved response', () {
    final json = jsonDecode(
      File('test/fixtures/open_meteo_sample.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('reads the current conditions', () {
      final snapshot = parse(json);
      expect(snapshot.now.temperature, 37.7);
      expect(snapshot.now.code, 1);
      expect(snapshot.now.isDay, isFalse);
    });

    test('keeps the six hours after the current hour, in order', () {
      final snapshot = parse(json);
      expect(snapshot.nextHours.length, 6);
      expect(snapshot.nextHours.map((h) => h.time.hour), [5, 6, 7, 8, 9, 10]);
      expect(snapshot.nextHours.map((h) => h.temperature), [37.7, 37.4, 37.3, 37.3, 38.4, 40.3]);
      expect(snapshot.nextHours.map((h) => h.code), [1, 1, 1, 2, 2, 2]);
      expect(snapshot.nextHours.map((h) => h.isDay), [false, false, false, true, true, true]);
    });

    test('remembers when, where, and in what unit it was fetched', () {
      final snapshot = parse(json);
      expect(snapshot.fetchedAtUtc, DateTime.utc(2026, 11, 12, 15, 20));
      expect(snapshot.latitude, 52.52);
      expect(snapshot.longitude, 13.41);
      expect(snapshot.unit, TemperatureUnit.fahrenheit);
    });
  });

  group('parseForecast with made-up responses', () {
    test('finds the current hour by the current time, not by position', () {
      // Current time is 12:40, so the current hour is 12:00 (third entry).
      final snapshot = parse(fakeResponse(currentTime: '2026-11-12T12:40'));
      expect(snapshot.nextHours.map((h) => h.time.hour), [13, 14, 15, 16]);
    });

    test('keeps fewer than six hours when the response has fewer', () {
      final snapshot = parse(fakeResponse(
        times: ['2026-11-12T10:00', '2026-11-12T11:00', '2026-11-12T12:00'],
        temps: [50.0, 51.0, 52.0],
        codes: [3, 3, 61],
        days: [1, 1, 1],
      ));
      expect(snapshot.nextHours.length, 2);
    });

    test('treats the first entry as the current hour when the time is not found', () {
      final snapshot = parse(fakeResponse(currentTime: '2030-01-01T00:20'));
      expect(snapshot.nextHours.length, 6);
      expect(snapshot.nextHours.first.time.hour, 11);
    });

    test('accepts whole-number temperatures', () {
      final snapshot = parse(fakeResponse(currentTemp: 50, temps: [50, 51, 52, 53, 54, 55, 56]));
      expect(snapshot.now.temperature, 50.0);
      expect(snapshot.nextHours.first.temperature, 51.0);
    });

    test('keeps a missing temperature as null instead of failing', () {
      final snapshot = parse(fakeResponse(temps: [50.0, null, 52.0, 53.0, 54.0, 55.0, 56.0]));
      expect(snapshot.nextHours.first.temperature, isNull);
      expect(snapshot.nextHours[1].temperature, 52.0);
    });

    test('keeps a missing weather code as null', () {
      final snapshot = parse(fakeResponse(codes: [3, null, 61, 61, 63, 2, 0]));
      expect(snapshot.nextHours.first.code, isNull);
    });

    test('reads the day/night flag as true or false', () {
      final snapshot = parse(fakeResponse(currentIsDay: 0));
      expect(snapshot.now.isDay, isFalse);
      final day = parse(fakeResponse(currentIsDay: 1));
      expect(day.now.isDay, isTrue);
    });

    test('rejects a response with no current block', () {
      final json = fakeResponse()..remove('current');
      expect(() => parse(json), throwsFormatException);
    });

    test('rejects a response with no hourly block', () {
      final json = fakeResponse()..remove('hourly');
      expect(() => parse(json), throwsFormatException);
    });

    test('rejects hourly lists of different lengths', () {
      final json = fakeResponse(temps: [50.0, 51.0]);
      expect(() => parse(json), throwsFormatException);
    });

    test('rejects a response with no current time', () {
      final json = fakeResponse();
      (json['current'] as Map<String, dynamic>).remove('time');
      expect(() => parse(json), throwsFormatException);
    });

    test('reports an API error message as a format problem', () {
      final json = <String, dynamic>{'error': true, 'reason': 'Latitude must be in range'};
      expect(() => parse(json), throwsFormatException);
    });
  });

  group('WeatherSnapshot JSON', () {
    test('survives a trip through JSON so it can be cached on the device', () {
      final snapshot = parse(fakeResponse(temps: [50.0, null, 52.0, 53.0, 54.0, 55.0, 56.0]));
      final again = WeatherSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );
      expect(again.fetchedAtUtc, snapshot.fetchedAtUtc);
      expect(again.latitude, snapshot.latitude);
      expect(again.longitude, snapshot.longitude);
      expect(again.unit, snapshot.unit);
      expect(again.now.temperature, snapshot.now.temperature);
      expect(again.now.code, snapshot.now.code);
      expect(again.now.isDay, snapshot.now.isDay);
      expect(again.nextHours.length, snapshot.nextHours.length);
      for (var i = 0; i < snapshot.nextHours.length; i++) {
        expect(again.nextHours[i].time.hour, snapshot.nextHours[i].time.hour);
        expect(again.nextHours[i].temperature, snapshot.nextHours[i].temperature);
        expect(again.nextHours[i].code, snapshot.nextHours[i].code);
        expect(again.nextHours[i].isDay, snapshot.nextHours[i].isDay);
      }
    });

    test('fromJson rejects a damaged cache', () {
      expect(() => WeatherSnapshot.fromJson(<String, dynamic>{'x': 1}), throwsFormatException);
    });
  });
}
