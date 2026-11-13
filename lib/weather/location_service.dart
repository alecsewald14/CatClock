import 'weather_problem.dart';

/// The answer to "where is this device?".
sealed class LocationResult {
  const LocationResult();
}

/// The device's position. It is rounded before it is ever sent anywhere.
class LocationFound extends LocationResult {
  const LocationFound(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// The position could not be found, and why.
class LocationFailed extends LocationResult {
  const LocationFailed(this.problem, [this.detail]);

  final WeatherProblem problem;

  /// Technical detail for developers. Never shown to the person.
  final String? detail;
}

/// Finds the device's current position.
abstract interface class LocationService {
  Future<LocationResult> current();
}
