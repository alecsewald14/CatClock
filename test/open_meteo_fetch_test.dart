import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cat_clock/weather/open_meteo_client.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_problem.dart';

final fixture = File('test/fixtures/open_meteo_sample.json').readAsStringSync();
final nowUtc = DateTime.utc(2026, 11, 12, 15, 30);

Future<Object?> fetchWith(
  http.Client client, {
  Duration timeout = const Duration(seconds: 5),
  double latitude = 52.5249,
  double longitude = 13.4151,
}) async {
  final api = OpenMeteoClient(client: client, timeout: timeout);
  try {
    return await api.fetch(
      latitude: latitude,
      longitude: longitude,
      unit: TemperatureUnit.fahrenheit,
      nowUtc: nowUtc,
    );
  } on WeatherFetchException catch (error) {
    return error;
  }
}

WeatherProblem problemOf(Object? result) => (result as WeatherFetchException).problem;

void main() {
  group('a good answer', () {
    test('becomes a weather snapshot', () async {
      final result = await fetchWith(MockClient((_) async => http.Response(fixture, 200)));
      final snapshot = result as dynamic;
      expect(snapshot.now.temperature, 37.7);
      expect(snapshot.nextHours.length, 6);
      expect(snapshot.fetchedAtUtc, nowUtc);
      expect(snapshot.unit, TemperatureUnit.fahrenheit);
    });

    test('asks for the right address, with coordinates rounded to 2 decimals', () async {
      late Uri asked;
      await fetchWith(MockClient((request) async {
        asked = request.url;
        return http.Response(fixture, 200);
      }));
      expect(asked.host, 'api.open-meteo.com');
      expect(asked.path, '/v1/forecast');
      expect(asked.queryParameters['latitude'], '52.52');
      expect(asked.queryParameters['longitude'], '13.42');
      expect(asked.queryParameters['forecast_hours'], '7');
      expect(asked.queryParameters['temperature_unit'], 'fahrenheit');
    });

    test('remembers the rounded coordinates, not the exact ones', () async {
      final result = await fetchWith(MockClient((_) async => http.Response(fixture, 200)));
      final snapshot = result as dynamic;
      expect(snapshot.latitude, 52.52);
      expect(snapshot.longitude, 13.42);
    });

    test('sends no personal details in the request', () async {
      late http.BaseRequest sent;
      await fetchWith(MockClient((request) async {
        sent = request;
        return http.Response(fixture, 200);
      }));
      expect(sent.method, 'GET');
      expect(sent.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      expect(sent.headers.keys.map((k) => k.toLowerCase()), isNot(contains('cookie')));
      expect(sent.url.userInfo, isEmpty);
    });
  });

  group('problems reaching the service', () {
    test('a server error counts as a network problem', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('oops', 500)));
      expect(problemOf(result), WeatherProblem.network);
    });

    test('"too many requests" counts as a network problem', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('slow down', 429)));
      expect(problemOf(result), WeatherProblem.network);
    });

    test('a refused connection counts as a network problem', () async {
      final result = await fetchWith(MockClient((_) async => throw const SocketException('no route')));
      expect(problemOf(result), WeatherProblem.network);
    });

    test('a client exception counts as a network problem', () async {
      final result = await fetchWith(MockClient((_) async => throw http.ClientException('lost')));
      expect(problemOf(result), WeatherProblem.network);
    });

    test('taking too long counts as a network problem', () async {
      final never = Completer<http.Response>();
      final result = await fetchWith(
        MockClient((_) => never.future),
        timeout: const Duration(milliseconds: 30),
      );
      expect(problemOf(result), WeatherProblem.network);
    });
  });

  group('answers that cannot be used', () {
    test('a request the service rejects is a bad response', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('{"error":true}', 400)));
      expect(problemOf(result), WeatherProblem.badResponse);
    });

    test('text that is not JSON is a bad response', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('<html>hi</html>', 200)));
      expect(problemOf(result), WeatherProblem.badResponse);
    });

    test('JSON that is not an object is a bad response', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('[1,2,3]', 200)));
      expect(problemOf(result), WeatherProblem.badResponse);
    });

    test('an error message inside a 200 answer is a bad response', () async {
      final body = jsonEncode({'error': true, 'reason': 'Latitude must be in range'});
      final result = await fetchWith(MockClient((_) async => http.Response(body, 200)));
      expect(problemOf(result), WeatherProblem.badResponse);
    });

    test('an answer with pieces missing is a bad response', () async {
      final result = await fetchWith(MockClient((_) async => http.Response('{"hourly":{}}', 200)));
      expect(problemOf(result), WeatherProblem.badResponse);
    });
  });

  group('WeatherProblem', () {
    test('every problem has a plain-language message', () {
      for (final problem in WeatherProblem.values) {
        expect(problem.message, isNotEmpty, reason: '$problem');
      }
    });

    test('messages do not blame the person or use technical words', () {
      for (final problem in WeatherProblem.values) {
        expect(problem.message.toLowerCase(), isNot(contains('exception')), reason: '$problem');
        expect(problem.message.toLowerCase(), isNot(contains('http')), reason: '$problem');
      }
    });
  });
}
