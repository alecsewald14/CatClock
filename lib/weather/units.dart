/// Which scale temperatures are shown in.
enum TemperatureUnit {
  celsius,
  fahrenheit;

  /// The word Open-Meteo expects in its `temperature_unit` setting.
  String get apiValue => name;
}

/// Fahrenheit for the United States, Celsius everywhere else.
///
/// [regionCode] is the two-letter country code of the device's region, such as `US`.
TemperatureUnit unitForRegion(String? regionCode) {
  if (regionCode != null && regionCode.toUpperCase() == 'US') {
    return TemperatureUnit.fahrenheit;
  }
  return TemperatureUnit.celsius;
}

/// A temperature as shown on screen: rounded to a whole degree, with a degree sign.
/// A missing value shows as `--°`. A tiny negative value never shows as `-0°`.
String formatTemperature(double? value) {
  if (value == null || !value.isFinite) return '--°';
  return '${value.round()}°';
}
