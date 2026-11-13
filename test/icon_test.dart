import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/cat_icon.dart';

import 'helpers/pump.dart';

Future<ui.Image> render(int size) async {
  final recorder = ui.PictureRecorder();
  const CatIconPainter().paint(ui.Canvas(recorder), Size(size.toDouble(), size.toDouble()));
  return recorder.endRecording().toImage(size, size);
}

void main() {
  testWidgets('the icon is fully opaque at every size', (tester) async {
    await tester.runAsync(() async {
      for (final size in [16, 32, 64, 256, 1024]) {
        final image = await render(size);
        final bytes = (await image.toByteData())!;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) != 255) fail('$size px icon has a see-through pixel');
        }
      }
    });
  });

  testWidgets('the two eyes are blue, and the face around them is orange', (tester) async {
    await tester.runAsync(() async {
      final image = await render(256);
      final bytes = (await image.toByteData())!;
      List<int> pixel(double x, double y) {
        final offset = ((y * 256).round() * 256 + (x * 256).round()) * 4;
        return [bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2)];
      }

      for (final x in [0.36, 0.64]) {
        final eye = pixel(x, 0.54);
        expect(eye[2], greaterThan(eye[0] + 60), reason: 'eye at $x is blue');
      }
      final cheek = pixel(0.25, 0.62);
      expect(cheek[0], greaterThan(cheek[2] + 40), reason: 'cheek is orange');
    });
  });

  testWidgets('saved image of the icon at four sizes', (tester) async {
    await pumpAtSize(
      tester,
      const Size(480, 300),
      Center(
        child: RepaintBoundary(
          key: const Key('shot'),
          child: Container(
            color: const Color(0xFF202020),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final size in [16.0, 32.0, 64.0, 200.0])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(width: size, height: size, child: const CustomPaint(painter: CatIconPainter())),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('goldens/cat_icon.png'));
  });

  testWidgets('the tray icon file exists and is a PNG', (tester) async {
    final file = File('assets/icons/cat_tray.png');
    expect(file.existsSync(), isTrue);
    final header = file.readAsBytesSync().sublist(0, 8);
    expect(header, [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  // Run once with  CATCLOCK_WRITE_ICONS=1  to (re)make the icon files.
  testWidgets('writes the icon files when asked to', (tester) async {
    if (Platform.environment['CATCLOCK_WRITE_ICONS'] != '1') return;
    await tester.runAsync(() async {
      final image = await render(64);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      Directory('assets/icons').createSync(recursive: true);
      File('assets/icons/cat_tray.png').writeAsBytesSync(data.buffer.asUint8List());
    });
  });
}
