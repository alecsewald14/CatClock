import 'volume_levels.dart';

/// One of the alarm sounds you can choose from.
class AlarmSound {
  const AlarmSound(this.id, this.name);

  /// The short name stored with the alarm, and used in file names.
  final String id;

  /// The name shown to the person.
  final String name;

  /// The file for [level], written by tool/make_sounds.dart.
  String assetPath(int level) {
    RangeError.checkValueInInterval(level, minVolumeLevel, maxVolumeLevel, 'level');
    return 'assets/sounds/${id}_$level.wav';
  }

  /// The loudest file, which Windows plays with the player volume turned down.
  String get fullVolumeAssetPath => assetPath(maxVolumeLevel);

  @override
  String toString() => 'AlarmSound($id)';
}

/// The six sounds, in the order they are listed. The first is the default.
const List<AlarmSound> alarmSounds = <AlarmSound>[
  AlarmSound('soft_chime', 'Soft Chime'),
  AlarmSound('classic_beep', 'Classic Beep'),
  AlarmSound('morning_bells', 'Morning Bells'),
  AlarmSound('purr_rise', 'Purr Rise'),
  AlarmSound('meow_melody', 'Meow Melody'),
  AlarmSound('cat_bell', 'Cat Bell'),
];

/// The sound with this [id], or the default one if there is none (for example if a saved
/// alarm names a sound that a later version of the app no longer has).
AlarmSound soundById(String id) {
  for (final sound in alarmSounds) {
    if (sound.id == id) return sound;
  }
  return alarmSounds.first;
}

/// True if [id] names one of the sounds.
bool isKnownSound(String id) => alarmSounds.any((sound) => sound.id == id);
