import 'package:flutter/foundation.dart';

/// How many pictures of the cat are made each second, at most.
const int catFramesPerSecond = 24;

/// One full step cycle (left foot, then right foot) takes one second.
const Duration walkCycleLength = Duration(seconds: 1);

/// The moments, in a repeating 16-second loop, when the cat starts a blink. The gaps
/// between blinks are 4.5, 3.1, 3.6, and 4.8 seconds, so it blinks every 3 to 5 seconds.
const List<double> blinkStartTimes = <double>[3.4, 7.9, 11.0, 14.6];
const double blinkLoopSeconds = 16;

/// A blink lasts this long, closing and opening again.
const double blinkSeconds = 0.16;

/// What the cat looks like at one instant.
@immutable
class CatPose {
  const CatPose({required this.phase, required this.blink});

  /// Where it is in the step cycle, from 0 up to (not including) 1.
  /// At 0 both feet are down.
  final double phase;

  /// How closed the eyes are: 0 open, 1 shut.
  final double blink;

  /// Standing still with eyes open.
  static const CatPose standing = CatPose(phase: 0, blink: 0);

  @override
  bool operator ==(Object other) =>
      other is CatPose && other.phase == phase && other.blink == blink;

  @override
  int get hashCode => Object.hash(phase, blink);

  @override
  String toString() => 'CatPose(phase: $phase, blink: $blink)';
}

/// How shut the eyes are [seconds] into the animation: 0 between blinks, rising to 1 in
/// the middle of a blink and falling back to 0.
double blinkAt(double seconds) {
  final t = seconds % blinkLoopSeconds;
  for (final start in blinkStartTimes) {
    if (t >= start && t < start + blinkSeconds) {
      final progress = (t - start) / blinkSeconds;
      return 1 - (2 * progress - 1).abs();
    }
  }
  return 0;
}

/// The cat's pose [elapsed] after the animation started.
CatPose poseAt(Duration elapsed) {
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return CatPose(phase: seconds % 1.0, blink: blinkAt(seconds));
}

/// The pose for picture number [frame], counting from 0. There are 24 pictures a second,
/// so frame 24 is exactly one second in and the step cycle starts over.
CatPose poseForFrame(int frame) {
  return poseAt(
    Duration(microseconds: frame * Duration.microsecondsPerSecond ~/ catFramesPerSecond),
  );
}
