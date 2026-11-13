import 'package:flutter/material.dart';

import '../cat/cat_painter.dart';
import '../cat/cat_view.dart';
import '../cat/walk_cycle.dart';
import '../display/belly_panel.dart';
import '../weather/weather_models.dart';
import '../weather/weather_rules.dart';

/// The cat with the screen on its belly, drawn on a 1000 by 900 sheet.
///
/// The screen is placed in the same spot whatever the cat is doing, so it never moves.
class CatScene extends StatelessWidget {
  const CatScene({
    super.key,
    required this.hour24,
    required this.minute,
    required this.colonOn,
    required this.weather,
    required this.freshness,
    required this.localNow,
    this.animate = true,
    this.pose,
    this.ringing = false,
  });

  final int hour24;
  final int minute;
  final bool colonOn;
  final WeatherSnapshot? weather;
  final WeatherFreshness freshness;
  final DateTime localNow;
  final bool animate;
  final ValueNotifier<CatPose>? pose;

  /// True while the alarm rings, so the digits pulse.
  final bool ringing;

  static const Size size = Size(catSceneWidth, catSceneHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('cat-scene'),
      width: catSceneWidth,
      height: catSceneHeight,
      child: Stack(
        children: [
          Positioned.fill(child: CatView(animate: animate, pose: pose)),
          Positioned(
            left: catBellyRect.left,
            top: catBellyRect.top,
            child: BellyPanel(
              hour24: hour24,
              minute: minute,
              colonOn: colonOn,
              weather: weather,
              freshness: freshness,
              localNow: localNow,
              ringing: ringing,
            ),
          ),
        ],
      ),
    );
  }
}
