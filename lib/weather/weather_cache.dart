import 'dart:convert';

import '../storage/text_storage.dart';
import 'weather_models.dart';

/// Keeps the last good weather result on the device, so something can be shown straight
/// away at start-up and while offline.
///
/// What is saved is the weather, when it was fetched, and the position rounded to about
/// 1 kilometre. Nothing else.
class WeatherCache {
  WeatherCache(this._storage);

  /// Bumped if the saved format ever changes.
  static const int formatVersion = 1;

  final TextStorage _storage;

  /// Why the last [load] found nothing usable, or null if it went fine.
  String? lastLoadProblem;

  Future<WeatherSnapshot?> load() async {
    lastLoadProblem = null;

    final String? text;
    try {
      text = await _storage.read();
    } catch (error) {
      lastLoadProblem = 'Could not read the saved weather: $error';
      return null;
    }
    if (text == null || text.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('The saved weather is not a JSON object');
      }
      if (decoded['version'] != formatVersion) {
        lastLoadProblem = 'The saved weather is from a different version (${decoded['version']})';
        return null;
      }
      final snapshot = decoded['snapshot'];
      if (snapshot is! Map) {
        throw const FormatException('The saved weather has no snapshot');
      }
      return WeatherSnapshot.fromJson(Map<String, dynamic>.from(snapshot));
    } on FormatException catch (error) {
      lastLoadProblem = 'The saved weather could not be used: ${error.message}';
      return null;
    }
  }

  Future<void> save(WeatherSnapshot snapshot) {
    final json = <String, dynamic>{'version': formatVersion, 'snapshot': snapshot.toJson()};
    return _storage.write(jsonEncode(json));
  }
}
