/// Why the weather could not be updated.
enum WeatherProblem {
  /// Location is switched off on this device.
  locationDisabled,

  /// Location is on, but this app was not given permission.
  locationDenied,

  /// Location is on and allowed, but the device could not work out where it is.
  locationUnavailable,

  /// The weather service could not be reached.
  network,

  /// The weather service answered with something the app cannot use.
  badResponse;

  /// A short sentence for the person using the app, with no technical words.
  String get message {
    switch (this) {
      case WeatherProblem.locationDisabled:
        return 'Weather needs your location, and location is turned off.';
      case WeatherProblem.locationDenied:
        return 'Weather needs your location, and permission was not given.';
      case WeatherProblem.locationUnavailable:
        return 'Could not find where this device is.';
      case WeatherProblem.network:
        return 'Could not reach the weather service.';
      case WeatherProblem.badResponse:
        return 'The weather service sent something unexpected.';
    }
  }
}
