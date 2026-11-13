import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import '../storage/text_storage.dart';
import 'geolocator_location_service.dart';
import 'open_meteo_client.dart';
import 'refresh_scheduler.dart';
import 'units.dart';
import 'weather_cache.dart';
import 'weather_repository.dart';

/// Builds the real weather machinery: the device's location, Open-Meteo over the
/// internet, and a saved copy of the last result in [dataDirectory].
WeatherRepository createWeatherRepository(Directory dataDirectory) {
  return WeatherRepository(
    location: const GeolocatorLocationService(),
    fetcher: OpenMeteoClient(),
    cache: WeatherCache(FileTextStorage(File('${dataDirectory.path}/weather_cache.json'))),
    nowUtc: () => DateTime.now().toUtc(),
    unit: () => unitForRegion(PlatformDispatcher.instance.locale.countryCode),
    scheduler: TimerRefreshScheduler(),
  );
}
