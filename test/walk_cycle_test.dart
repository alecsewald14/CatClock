import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/cat/walk_cycle.dart';

void main() {
  group('poseAt', () {
    test('starts standing with both feet down and eyes open', () {
      expect(poseAt(Duration.zero), CatPose.standing);
    });

    test('is half way through a step cycle after half a second', () {
      expect(poseAt(const Duration(milliseconds: 500)).phase, closeTo(0.5, 1e-9));
    });

    test('a step cycle takes one second', () {
      for (var frame = 0; frame < 24; frame++) {
        final now = Duration(microseconds: frame * 1000000 ~/ 24);
        final later = now + walkCycleLength;
        expect(poseAt(later).phase, closeTo(poseAt(now).phase, 1e-9), reason: 'frame $frame');
      }
    });

    test('the phase always stays from 0 up to but not including 1', () {
      for (var ms = 0; ms < 5000; ms += 7) {
        final phase = poseAt(Duration(milliseconds: ms)).phase;
        expect(phase, greaterThanOrEqualTo(0));
        expect(phase, lessThan(1));
      }
    });

    test('the whole animation loops every 16 seconds', () {
      const offset = Duration(milliseconds: 3450);
      expect(
        poseAt(offset + const Duration(seconds: 16)).blink,
        closeTo(poseAt(offset).blink, 1e-9),
      );
    });
  });

  group('frames', () {
    test('there are 24 frames a second', () {
      expect(catFramesPerSecond, 24);
    });

    test('frame 0 is the standing pose', () {
      expect(poseForFrame(0), CatPose.standing);
    });

    test('frame 12 is half way through the step', () {
      expect(poseForFrame(12).phase, closeTo(0.5, 1e-9));
    });

    test('frame 24 is exactly one second in, so the step starts over', () {
      expect(poseForFrame(24).phase, 0);
    });

    test('one step cycle has 24 different poses', () {
      final phases = <double>{for (var frame = 0; frame < 24; frame++) poseForFrame(frame).phase};
      expect(phases.length, 24);
    });

    test('every later cycle repeats the first', () {
      for (var frame = 0; frame < 24; frame++) {
        for (final cycle in [1, 2, 5]) {
          expect(
            poseForFrame(frame + 24 * cycle).phase,
            closeTo(poseForFrame(frame).phase, 1e-9),
            reason: 'frame $frame, cycle $cycle',
          );
        }
      }
    });
  });

  group('blinking', () {
    test('there is a blink every 3 to 5 seconds, counting the wrap-around', () {
      for (var i = 0; i < blinkStartTimes.length; i++) {
        final next = i + 1 < blinkStartTimes.length
            ? blinkStartTimes[i + 1]
            : blinkStartTimes.first + blinkLoopSeconds;
        final gap = next - blinkStartTimes[i];
        expect(gap, inInclusiveRange(3, 5), reason: 'after blink $i');
      }
    });

    test('eyes are open between blinks', () {
      expect(blinkAt(0), 0);
      expect(blinkAt(1.2), 0);
      expect(blinkAt(5), 0);
    });

    test('eyes are fully shut in the middle of a blink', () {
      expect(blinkAt(blinkStartTimes.first + blinkSeconds / 2), closeTo(1, 1e-9));
    });

    test('eyes are open again once the blink ends', () {
      expect(blinkAt(blinkStartTimes.first + blinkSeconds), 0);
    });

    test('a blink closes and then opens, it does not jump', () {
      final start = blinkStartTimes.first;
      final quarter = blinkAt(start + blinkSeconds * 0.25);
      final half = blinkAt(start + blinkSeconds * 0.5);
      final threeQuarters = blinkAt(start + blinkSeconds * 0.75);
      expect(quarter, closeTo(0.5, 1e-9));
      expect(half, greaterThan(quarter));
      expect(threeQuarters, closeTo(0.5, 1e-9));
    });

    test('blink is always between 0 and 1', () {
      for (var ms = 0; ms < 32000; ms += 10) {
        final blink = blinkAt(ms / 1000);
        expect(blink, inInclusiveRange(0, 1));
      }
    });
  });

  group('CatPose', () {
    test('poses with the same values are equal', () {
      expect(const CatPose(phase: 0.25, blink: 0), const CatPose(phase: 0.25, blink: 0));
      expect(const CatPose(phase: 0.25, blink: 0), isNot(const CatPose(phase: 0.5, blink: 0)));
    });
  });
}
