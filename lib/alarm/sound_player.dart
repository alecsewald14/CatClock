import 'sound_catalog.dart';

/// Plays the alarm and the short samples. The real one talks to the speakers; tests use a
/// fake that just records what it was asked to do.
abstract interface class SoundPlayer {
  /// Plays [sound] over and over at volume [level] until [stop] is called.
  Future<void> playAlarm(AlarmSound sound, int level);

  /// Plays a short sample, for choosing a sound or checking the volume. It stops by itself
  /// after a few seconds.
  Future<void> playPreview(AlarmSound sound, int level);

  /// Stops whatever is playing. Does nothing if nothing is.
  Future<void> stop();

  /// Lets go of the speakers.
  Future<void> dispose();
}
