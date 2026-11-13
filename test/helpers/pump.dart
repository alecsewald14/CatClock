import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/theme.dart';

/// Shows [widget] in a window of [size] logical pixels, drawn at [pixelRatio] times
/// that size, so saved images are sharp enough to judge by eye.
///
/// [reduceMotion] acts like the device's "reduce motion" setting, and [textScale] like
/// its text-size setting.
Future<void> pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget widget, {
  double pixelRatio = 1,
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      // Text needs a Material ancestor for its default style; the real screen gets one
      // from its Scaffold.
      home: Material(type: MaterialType.transparency, child: widget),
    ),
  );
}
