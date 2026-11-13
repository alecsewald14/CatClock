/// The 12 weather pictures the app can show.
enum WeatherIcon {
  clearDay,
  clearNight,
  partlyDay,
  partlyNight,
  cloudy,
  fog,
  drizzle,
  rain,
  sleet,
  snow,
  thunder,

  /// Shown when there is no data, or a weather code the app does not know.
  unavailable,
}

/// Picks the picture for an Open-Meteo weather code (the standard WMO codes).
///
/// [isDay] only matters for clear and partly cloudy skies, where it chooses between a sun
/// and a moon. If it is unknown, daytime is assumed.
WeatherIcon iconFor(int? code, {required bool? isDay}) {
  if (code == null) return WeatherIcon.unavailable;
  final day = isDay ?? true;
  switch (code) {
    case 0: // clear sky
    case 1: // mainly clear
      return day ? WeatherIcon.clearDay : WeatherIcon.clearNight;
    case 2: // partly cloudy
      return day ? WeatherIcon.partlyDay : WeatherIcon.partlyNight;
    case 3: // overcast
      return WeatherIcon.cloudy;
    case 45: // fog
    case 48: // depositing rime fog
      return WeatherIcon.fog;
    case 51: // light drizzle
    case 53: // moderate drizzle
    case 55: // dense drizzle
      return WeatherIcon.drizzle;
    case 56: // light freezing drizzle
    case 57: // dense freezing drizzle
    case 66: // light freezing rain
    case 67: // heavy freezing rain
      return WeatherIcon.sleet;
    case 61: // slight rain
    case 63: // moderate rain
    case 65: // heavy rain
    case 80: // slight rain showers
    case 81: // moderate rain showers
    case 82: // violent rain showers
      return WeatherIcon.rain;
    case 71: // slight snowfall
    case 73: // moderate snowfall
    case 75: // heavy snowfall
    case 77: // snow grains
    case 85: // slight snow showers
    case 86: // heavy snow showers
      return WeatherIcon.snow;
    case 95: // thunderstorm
    case 96: // thunderstorm with slight hail
    case 97: // heavy thunderstorm
    case 99: // thunderstorm with heavy hail
      return WeatherIcon.thunder;
    default:
      return WeatherIcon.unavailable;
  }
}
