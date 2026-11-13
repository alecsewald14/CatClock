import 'units.dart';
import 'weather_models.dart';
import 'weather_rules.dart';

/// How many hourly entries to ask for: the current hour plus the next six.
const int forecastHoursRequested = 7;

/// How many hours after the current one are kept for display.
const int hoursAfterNow = 6;

/// The web address that asks Open-Meteo for current conditions and the next hours at a
/// place. The coordinates are rounded to 2 decimals (about 1 km) here, so nothing more
/// precise ever leaves the device.
Uri buildForecastUri({
  required double latitude,
  required double longitude,
  required TemperatureUnit unit,
}) {
  return Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
    'latitude': roundCoordinate(latitude).toString(),
    'longitude': roundCoordinate(longitude).toString(),
    'current': 'temperature_2m,weather_code,is_day',
    'hourly': 'temperature_2m,weather_code,is_day',
    'forecast_hours': '$forecastHoursRequested',
    'temperature_unit': unit.apiValue,
    'timezone': 'auto',
  });
}

/// Turns Open-Meteo's answer into a [WeatherSnapshot].
///
/// The first hourly entry is normally the current hour, so the hours after it are the
/// "next six". The current hour is found by matching the response's own current time, and
/// the first entry is used if no match is found.
///
/// Throws a [FormatException] if the answer is an error or is missing pieces.
WeatherSnapshot parseForecast(
  Map<String, dynamic> json, {
  required DateTime fetchedAtUtc,
  required double latitude,
  required double longitude,
  required TemperatureUnit unit,
}) {
  if (json['error'] == true) {
    throw FormatException('Open-Meteo reported an error: ${json['reason'] ?? 'no reason given'}');
  }
  final current = json['current'];
  final hourly = json['hourly'];
  if (current is! Map) throw const FormatException('The weather answer has no "current" part');
  if (hourly is! Map) throw const FormatException('The weather answer has no "hourly" part');

  final currentTime = current['time'];
  if (currentTime is! String || currentTime.length < 13) {
    throw const FormatException('The weather answer has no current time');
  }

  final times = _list(hourly, 'time');
  final temperatures = _list(hourly, 'temperature_2m');
  final codes = _list(hourly, 'weather_code');
  final days = _list(hourly, 'is_day');
  if (temperatures.length != times.length ||
      codes.length != times.length ||
      days.length != times.length) {
    throw const FormatException('The hourly weather lists are not the same length');
  }

  // "2026-11-13T04:45" belongs to the hour "2026-11-13T04:00".
  final currentHour = '${currentTime.substring(0, 13)}:00';
  var currentIndex = times.indexOf(currentHour);
  if (currentIndex < 0) currentIndex = 0;

  final nextHours = <HourWeather>[];
  for (var i = currentIndex + 1; i < times.length && nextHours.length < hoursAfterNow; i++) {
    final time = times[i];
    if (time is! String) throw const FormatException('An hourly time is not text');
    nextHours.add(HourWeather(
      time: DateTime.parse(time),
      temperature: _toDouble(temperatures[i]),
      code: _toInt(codes[i]),
      isDay: _toDayFlag(days[i]),
    ));
  }

  return WeatherSnapshot(
    fetchedAtUtc: fetchedAtUtc,
    latitude: latitude,
    longitude: longitude,
    unit: unit,
    now: WeatherNow(
      temperature: _toDouble(current['temperature_2m']),
      code: _toInt(current['weather_code']),
      isDay: _toDayFlag(current['is_day']),
    ),
    nextHours: nextHours,
  );
}

List<dynamic> _list(Map<dynamic, dynamic> block, String key) {
  final value = block[key];
  if (value is! List) throw FormatException('The weather answer has no "$key" list');
  return value;
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected a number but got $value');
}

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw FormatException('Expected a number but got $value');
}

/// Open-Meteo sends 1 for day and 0 for night.
bool? _toDayFlag(Object? value) {
  if (value == null) return null;
  if (value is num) return value != 0;
  throw FormatException('Expected 0 or 1 but got $value');
}
