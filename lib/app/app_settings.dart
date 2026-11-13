import 'dart:convert';

import '../storage/text_storage.dart';

/// Small things the app remembers between runs.
class AppSettings {
  const AppSettings({this.trayNoticeSeen = false});

  /// True once the person has been told that closing the window keeps the app running in
  /// the system tray, so the alarm can still ring.
  final bool trayNoticeSeen;

  AppSettings copyWith({bool? trayNoticeSeen}) =>
      AppSettings(trayNoticeSeen: trayNoticeSeen ?? this.trayNoticeSeen);

  Map<String, dynamic> toJson() => <String, dynamic>{'trayNoticeSeen': trayNoticeSeen};

  @override
  bool operator ==(Object other) => other is AppSettings && other.trayNoticeSeen == trayNoticeSeen;

  @override
  int get hashCode => trayNoticeSeen.hashCode;
}

/// Loads and saves [AppSettings]. Loading never fails: a missing or damaged file gives the
/// defaults.
class AppSettingsStore {
  AppSettingsStore(this._storage);

  static const int formatVersion = 1;

  final TextStorage _storage;

  Future<AppSettings> load() async {
    try {
      final text = await _storage.read();
      if (text == null || text.trim().isEmpty) return const AppSettings();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const AppSettings();
      final seen = decoded['trayNoticeSeen'];
      return AppSettings(trayNoticeSeen: seen is bool ? seen : false);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _storage.write(jsonEncode(<String, dynamic>{'version': formatVersion, ...settings.toJson()}));
  }
}
