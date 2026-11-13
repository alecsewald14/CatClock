/// The one alarm the app keeps: when it rings, whether it is on, and how it sounds.
class Alarm {
  const Alarm({
    this.hour = 7,
    this.minute = 0,
    this.enabled = false,
    this.repeatDaily = false,
    this.soundId = 'soft_chime',
    this.volumeLevel = 3,
  });

  /// Lowest and highest loudness levels on the volume slider.
  static const int minVolumeLevel = 1;
  static const int maxVolumeLevel = 5;

  /// Hour of the day from 0 to 23, on the 24-hour scale.
  final int hour;

  /// Minute from 0 to 59.
  final int minute;

  /// Whether the alarm is switched on.
  final bool enabled;

  /// Whether the alarm comes back every day after it is stopped.
  final bool repeatDaily;

  /// Which sound plays. The names are decided by the sound catalog.
  final String soundId;

  /// Loudness level from 1 (quietest) to 5 (loudest).
  final int volumeLevel;

  Alarm copyWith({
    int? hour,
    int? minute,
    bool? enabled,
    bool? repeatDaily,
    String? soundId,
    int? volumeLevel,
  }) {
    return Alarm(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      soundId: soundId ?? this.soundId,
      volumeLevel: volumeLevel ?? this.volumeLevel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'repeatDaily': repeatDaily,
        'soundId': soundId,
        'volumeLevel': volumeLevel,
      };

  /// Reads an alarm back from saved JSON.
  ///
  /// Throws a [FormatException] if anything is missing, of the wrong type, or out of range,
  /// so a damaged file never produces a half-working alarm. Keys it does not know are ignored.
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      hour: _readInt(json, 'hour', 0, 23),
      minute: _readInt(json, 'minute', 0, 59),
      enabled: _readBool(json, 'enabled'),
      repeatDaily: _readBool(json, 'repeatDaily'),
      soundId: _readText(json, 'soundId'),
      volumeLevel: _readInt(json, 'volumeLevel', minVolumeLevel, maxVolumeLevel),
    );
  }

  static int _readInt(Map<String, dynamic> json, String key, int min, int max) {
    final value = json[key];
    if (value is! int) {
      throw FormatException('"$key" must be a whole number, but was $value');
    }
    if (value < min || value > max) {
      throw FormatException('"$key" must be from $min to $max, but was $value');
    }
    return value;
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('"$key" must be true or false, but was $value');
    }
    return value;
  }

  static String _readText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('"$key" must be some text, but was $value');
    }
    return value;
  }

  @override
  bool operator ==(Object other) {
    return other is Alarm &&
        other.hour == hour &&
        other.minute == minute &&
        other.enabled == enabled &&
        other.repeatDaily == repeatDaily &&
        other.soundId == soundId &&
        other.volumeLevel == volumeLevel;
  }

  @override
  int get hashCode => Object.hash(hour, minute, enabled, repeatDaily, soundId, volumeLevel);

  @override
  String toString() => 'Alarm($hour:${minute.toString().padLeft(2, '0')}, '
      'enabled: $enabled, repeatDaily: $repeatDaily, sound: $soundId, volume: $volumeLevel)';
}
