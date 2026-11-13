// A developer check of the real weather connection, using fixed sample coordinates
// (central Berlin) so no one's real location is involved.
//
// Run from the project folder:
//   dart run tool/weather_live_check.dart
import 'package:cat_clock/weather/open_meteo_client.dart';
import 'package:cat_clock/weather/units.dart';

Future<void> main() async {
  final client = OpenMeteoClient();
  final nowUtc = DateTime.now().toUtc();
  try {
    final snapshot = await client.fetch(
      latitude: 52.5200,
      longitude: 13.4050,
      unit: TemperatureUnit.celsius,
      nowUtc: nowUtc,
    );
    print('Reached Open-Meteo.');
    print('Position used (rounded): ${snapshot.latitude}, ${snapshot.longitude}');
    print('Now: ${snapshot.now.temperature} degrees C, code ${snapshot.now.code}, '
        'daytime: ${snapshot.now.isDay}');
    print('Next ${snapshot.nextHours.length} hours:');
    for (final hour in snapshot.nextHours) {
      print('  ${hour.time.toIso8601String().substring(0, 16)}  '
          '${hour.temperature} degrees C, code ${hour.code}');
    }
  } on WeatherFetchException catch (error) {
    print('Failed: $error');
  }
}
