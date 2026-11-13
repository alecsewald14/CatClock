import '../weather/units.dart';
import '../weather/weather_models.dart';

bool _isDaylight(int hour) => hour >= 7 && hour < 19;

/// Made-up weather for the screen, used by tests and by builds that do not fetch real
/// weather yet. It is never shown as real data.
WeatherSnapshot sampleWeather(DateTime localNow) {
  const codes = <int>[3, 61, 61, 63, 2, 0];
  const temperatures = <double>[53, 52, 51, 50, 49, 48];
  final start = DateTime(localNow.year, localNow.month, localNow.day, localNow.hour);
  return WeatherSnapshot(
    fetchedAtUtc: localNow.toUtc(),
    latitude: 0,
    longitude: 0,
    unit: TemperatureUnit.fahrenheit,
    now: WeatherNow(temperature: 54, code: 2, isDay: _isDaylight(localNow.hour)),
    nextHours: [
      for (var i = 0; i < 6; i++)
        HourWeather(
          time: start.add(Duration(hours: i + 1)),
          temperature: temperatures[i],
          code: codes[i],
          isDay: _isDaylight(start.add(Duration(hours: i + 1)).hour),
        ),
    ],
  );
}
