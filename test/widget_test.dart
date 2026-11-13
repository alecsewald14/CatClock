import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/main.dart';

void main() {
  testWidgets('the app opens on the cat clock screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CatClockApp());

    expect(find.byKey(const Key('belly-panel')), findsOneWidget);
    expect(find.byKey(const Key('alarm-bar')), findsOneWidget);
    expect(find.byKey(const Key('cat')), findsOneWidget);

    // Leave the tree so the cat's timer and the clock's timer are cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
