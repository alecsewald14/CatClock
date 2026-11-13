import 'package:cat_clock/alarm/second_ticker.dart';
import 'package:cat_clock/alarm/sound_catalog.dart';
import 'package:cat_clock/alarm/sound_player.dart';

/// Writes down what it was asked to play instead of playing it.
class FakeSoundPlayer implements SoundPlayer {
  final List<String> events = [];
  bool failToPlayAlarm = false;
  bool failToStop = false;
  bool disposed = false;

  bool get alarmIsPlaying {
    var playing = false;
    for (final event in events) {
      if (event.startsWith('alarm:')) playing = true;
      if (event == 'stop') playing = false;
    }
    return playing;
  }

  int count(String prefix) => events.where((e) => e.startsWith(prefix)).length;

  @override
  Future<void> playAlarm(AlarmSound sound, int level) async {
    if (failToPlayAlarm) throw StateError('no sound device');
    events.add('alarm:${sound.id}:$level');
  }

  @override
  Future<void> playPreview(AlarmSound sound, int level) async {
    events.add('preview:${sound.id}:$level');
  }

  @override
  Future<void> stop() async {
    if (failToStop) throw StateError('cannot stop');
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// A once-a-second timer the test ticks by hand.
class FakeTicker implements SecondTicker {
  void Function()? _onTick;
  bool running = false;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
    running = true;
  }

  @override
  void stop() {
    _onTick = null;
    running = false;
  }

  void tick() => _onTick?.call();
}
