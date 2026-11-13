import 'units.dart';

/// Current conditions.
class WeatherNow {
  const WeatherNow({this.temperature, this.code, this.isDay});

  /// In the unit the snapshot was fetched in. Null if the service gave no value.
  final double? temperature;

  /// An Open-Meteo weather code.
  final int? code;

  /// True in daylight, false at night, null if unknown.
  final bool? isDay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperature': temperature,
        'code': code,
        'isDay': isDay,
      };

  factory WeatherNow.fromJson(Map<String, dynamic> json) {
    return WeatherNow(
      temperature: _optionalDouble(json, 'temperature'),
      code: _optionalInt(json, 'code'),
      isDay: _optionalBool(json, 'isDay'),
    );
  }
}

/// The forecast for one hour.
class HourWeather {
  const HourWeather({required this.time, this.temperature, this.code, this.isDay});

  /// The hour, on the wall clock of the place the weather is for.
  final DateTime time;

  final double? temperature;
  final int? code;
  final bool? isDay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time.toIso8601String(),
        'temperature': temperature,
        'code': code,
        'isDay': isDay,
      };

  factory HourWeather.fromJson(Map<String, dynamic> json) {
    final time = json['time'];
    if (time is! String) {
      throw FormatException('An hour needs a "time" text, but had $time');
    }
    return HourWeather(
      time: DateTime.parse(time),
      temperature: _optionalDouble(json, 'temperature'),
      code: _optionalInt(json, 'code'),
      isDay: _optionalBool(json, 'isDay'),
    );
  }
}

/// One weather result: now, plus the next hours, with when and where it was fetched.
/// It is saved on the device so the last good result can still be shown offline.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAtUtc,
    required this.latitude,
    required this.longitude,
    required this.unit,
    required this.now,
    required this.nextHours,
  });

  final DateTime fetchedAtUtc;

  /// Rounded to 2 decimals.
  final double latitude;
  final double longitude;

  final TemperatureUnit unit;
  final WeatherNow now;

  /// Up to six hours after the current hour, in order.
  final List<HourWeather> nextHours;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fetchedAtUtc': fetchedAtUtc.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'unit': unit.name,
        'now': now.toJson(),
        'nextHours': [for (final hour in nextHours) hour.toJson()],
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final fetched = json['fetchedAtUtc'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final unitName = json['unit'];
    final now = json['now'];
    final hours = json['nextHours'];
    if (fetched is! String ||
        latitude is! num ||
        longitude is! num ||
        unitName is! String ||
        now is! Map ||
        hours is! List) {
      throw const FormatException('The saved weather is damaged');
    }
    final unit = TemperatureUnit.values.where((u) => u.name == unitName);
    if (unit.isEmpty) {
      throw FormatException('Unknown temperature unit "$unitName"');
    }
    return WeatherSnapshot(
      fetchedAtUtc: DateTime.parse(fetched).toUtc(),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      unit: unit.first,
      now: WeatherNow.fromJson(Map<String, dynamic>.from(now)),
      nextHours: [
        for (final hour in hours)
          if (hour is Map)
            HourWeather.fromJson(Map<String, dynamic>.from(hour))
          else
            throw const FormatException('An hour in the saved weather is damaged'),
      ],
    );
  }
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('"$key" must be a number, but was $value');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw FormatException('"$key" must be a number, but was $value');
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('"$key" must be true or false, but was $value');
}
