import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'weather_problem.dart';

/// Finds the device's position with the operating system's location service.
///
/// A low accuracy is asked for on purpose: weather only needs the town, and the position
/// is rounded to about 1 kilometre before it is used.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeLimit = const Duration(seconds: 20)});

  /// How long to wait for the device to work out where it is.
  final Duration timeLimit;

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFailed(WeatherProblem.locationDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationFailed(WeatherProblem.locationDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.low, timeLimit: timeLimit),
      );
      return LocationFound(position.latitude, position.longitude);
    } on TimeoutException {
      return const LocationFailed(WeatherProblem.locationUnavailable, 'Timed out');
    } catch (error) {
      return LocationFailed(WeatherProblem.locationUnavailable, '$error');
    }
  }
}
