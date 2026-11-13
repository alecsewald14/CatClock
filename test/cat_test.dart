import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/cat_scene.dart';
import 'package:cat_clock/app/sample_weather.dart';
import 'package:cat_clock/cat/cat_painter.dart';
import 'package:cat_clock/cat/cat_view.dart';
import 'package:cat_clock/cat/walk_cycle.dart';
import 'package:cat_clock/weather/weather_rules.dart';

import 'helpers/pump.dart';

final localNow = DateTime(2026, 11, 12, 19, 42);

CatScene scene(ValueNotifier<CatPose> pose, {bool animate = false}) {
  return CatScene(
    hour24: 19,
    minute: 42,
    colonOn: true,
    weather: sampleWeather(localNow),
    freshness: WeatherFreshness.fresh,
    localNow: localNow,
    animate: animate,
    pose: pose,
  );
}

/// The cat drawn at [pose], as raw pixels.
Future<List<int>> picture(CatPose pose) async {
  final recorder = ui.PictureRecorder();
  CatPainter(ValueNotifier<CatPose>(pose)).paint(ui.Canvas(recorder), const Size(500, 450));
  final image = await recorder.endRecording().toImage(500, 450);
  return (await image.toByteData())!.buffer.asUint8List();
}

void main() {
  group('the screen on the belly', () {
    testWidgets('stays in exactly the same place in every one of the 24 frames', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      await pumpAtSize(tester, CatScene.size, Align(alignment: Alignment.topLeft, child: scene(pose)));

      final first = tester.getRect(find.byKey(const Key('belly-panel')));
      expect(first, catBellyRect, reason: 'sits where the cat sheet leaves room for it');

      for (var frame = 0; frame < 24; frame++) {
        pose.value = poseForFrame(frame);
        await tester.pump();
        expect(tester.getRect(find.byKey(const Key('belly-panel'))), first, reason: 'frame $frame');
        expect(tester.getRect(find.byKey(const Key('digits'))).topLeft,
            isNot(const Offset(0, 0)));
      }
    });

    testWidgets('the digits do not move either', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      await pumpAtSize(tester, CatScene.size, Align(alignment: Alignment.topLeft, child: scene(pose)));
      final before = tester.getRect(find.byKey(const Key('digits')));
      pose.value = poseAt(const Duration(milliseconds: 250));
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('digits'))), before);
    });
  });

  group('the cat itself', () {
    testWidgets('looks different at different points of the step', (tester) async {
      await tester.runAsync(() async {
        final standing = await picture(const CatPose(phase: 0, blink: 0));
        final leftUp = await picture(const CatPose(phase: 0.25, blink: 0));
        final rightUp = await picture(const CatPose(phase: 0.75, blink: 0));
        expect(leftUp, isNot(standing));
        expect(rightUp, isNot(standing));
        expect(leftUp, isNot(rightUp), reason: 'one foot up, then the other');
      });
    });

    testWidgets('draws the same picture for the same pose every time', (tester) async {
      await tester.runAsync(() async {
        final a = await picture(const CatPose(phase: 0.4, blink: 0));
        final b = await picture(const CatPose(phase: 0.4, blink: 0));
        expect(a, b);
      });
    });

    testWidgets('closes its eyes when it blinks', (tester) async {
      await tester.runAsync(() async {
        final open = await picture(const CatPose(phase: 0, blink: 0));
        final shut = await picture(const CatPose(phase: 0, blink: 1));
        expect(shut, isNot(open));
      });
    });

    testWidgets('repeats exactly after one step cycle', (tester) async {
      await tester.runAsync(() async {
        final start = await picture(poseAt(Duration.zero));
        final later = await picture(poseAt(const Duration(seconds: 1)));
        expect(later, start);
      });
    });
  });

  group('moving and stopping', () {
    testWidgets('makes at most 24 pictures a second', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      var changes = 0;
      pose.addListener(() => changes++);
      await pumpAtSize(
        tester,
        const Size(500, 450),
        SizedBox(width: 500, height: 450, child: CatView(pose: pose)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(changes, inInclusiveRange(23, 24));

      // Leave the screen so the timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stands still when "reduce motion" is on', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      var changes = 0;
      pose.addListener(() => changes++);
      await pumpAtSize(
        tester,
        const Size(500, 450),
        SizedBox(width: 500, height: 450, child: CatView(pose: pose)),
        reduceMotion: true,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(changes, 0);
      expect(pose.value, CatPose.standing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stands still when told not to animate', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      var changes = 0;
      pose.addListener(() => changes++);
      await pumpAtSize(
        tester,
        const Size(500, 450),
        SizedBox(width: 500, height: 450, child: CatView(pose: pose, animate: false)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(changes, 0);
    });

    testWidgets('stops while the app is hidden and starts again when it comes back', (tester) async {
      final pose = ValueNotifier<CatPose>(CatPose.standing);
      var changes = 0;
      pose.addListener(() => changes++);
      await pumpAtSize(
        tester,
        const Size(500, 450),
        SizedBox(width: 500, height: 450, child: CatView(pose: pose)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      final whileHidden = changes;
      await tester.pump(const Duration(seconds: 2));
      expect(changes, whileHidden, reason: 'nothing moves while hidden');
      expect(pose.value, CatPose.standing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, greaterThan(whileHidden), reason: 'walking again');

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('saved image', () {
    testWidgets('standing, left foot up, and right foot up', (tester) async {
      Widget cat(CatPose pose) {
        return SizedBox(
          width: 500,
          height: 450,
          child: FittedBox(child: scene(ValueNotifier<CatPose>(pose))),
        );
      }

      await pumpAtSize(
        tester,
        const Size(1560, 470),
        Center(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: Container(
              color: const Color(0xFF05070D),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cat(const CatPose(phase: 0, blink: 0)),
                  const SizedBox(width: 10),
                  cat(const CatPose(phase: 0.25, blink: 0)),
                  const SizedBox(width: 10),
                  cat(const CatPose(phase: 0.75, blink: 1)),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/cat_poses.png'));
    });
  });
}
