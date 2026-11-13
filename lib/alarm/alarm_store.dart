import 'dart:convert';

import 'alarm.dart';

/// Somewhere to keep the saved alarm as text. The real app uses a file on the device;
/// tests use [MemoryAlarmStorage].
abstract class AlarmStorage {
  /// The saved text, or null if nothing has been saved yet.
  Future<String?> read();

  Future<void> write(String contents);
}

/// Keeps the saved text in memory. Used in tests, and as a fallback.
class MemoryAlarmStorage implements AlarmStorage {
  MemoryAlarmStorage([this.contents]);

  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async {
    this.contents = contents;
  }
}

/// Loads and saves the alarm.
///
/// Loading never fails: if the saved file is missing or damaged, the default alarm is
/// returned and [lastLoadProblem] says what went wrong, so the app keeps working.
class AlarmStore {
  AlarmStore(this._storage);

  /// Bumped if the saved format ever changes.
  static const int formatVersion = 1;

  final AlarmStorage _storage;

  /// Why the last [load] used the default alarm, or null if it went fine.
  String? lastLoadProblem;

  Future<Alarm> load() async {
    lastLoadProblem = null;

    final String? text;
    try {
      text = await _storage.read();
    } catch (error) {
      lastLoadProblem = 'Could not read the saved alarm: $error';
      return const Alarm();
    }
    if (text == null || text.trim().isEmpty) return const Alarm();

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('The saved alarm is not a JSON object');
      }
      return Alarm.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (error) {
      lastLoadProblem = 'The saved alarm could not be used: ${error.message}';
      return const Alarm();
    }
  }

  Future<void> save(Alarm alarm) {
    final json = <String, dynamic>{'version': formatVersion, ...alarm.toJson()};
    return _storage.write(jsonEncode(json));
  }
}
