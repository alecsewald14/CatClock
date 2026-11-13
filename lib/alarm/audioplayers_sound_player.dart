import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sound_catalog.dart';
import 'sound_player.dart';
import 'volume_levels.dart';

/// Plays sounds through the computer's speakers with the `audioplayers` package.
///
/// It plays the loudest file of each sound and sets the player volume from the level
/// (see [gainForLevel]).
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer({this.previewLength = const Duration(seconds: 3)});

  /// How long a preview plays before it stops by itself.
  final Duration previewLength;

  final AudioPlayer _player = AudioPlayer();
  Timer? _previewTimer;

  Future<void> _play(AlarmSound sound, int level, ReleaseMode mode) async {
    _previewTimer?.cancel();
    await _player.stop();
    await _player.setReleaseMode(mode);
    await _player.setVolume(gainForLevel(level));
    // AssetSource paths start inside the assets folder.
    final path = sound.fullVolumeAssetPath.substring('assets/'.length);
    await _player.play(AssetSource(path));
  }

  @override
  Future<void> playAlarm(AlarmSound sound, int level) {
    return _play(sound, level, ReleaseMode.loop);
  }

  @override
  Future<void> playPreview(AlarmSound sound, int level) async {
    await _play(sound, level, ReleaseMode.stop);
    _previewTimer = Timer(previewLength, () {
      _player.stop();
    });
  }

  @override
  Future<void> stop() async {
    _previewTimer?.cancel();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _previewTimer?.cancel();
    await _player.dispose();
  }
}
