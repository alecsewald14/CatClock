import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/cat_icon.dart';

import '../tool/png.dart';

const iconFolder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// The icon files the iPhone project asks for, from its own Contents.json:
/// file name and size in pixels.
List<({String file, int pixels})> requiredIcons() {
  final json = jsonDecode(File('$iconFolder/Contents.json').readAsStringSync()) as Map<String, dynamic>;
  final found = <String, int>{};
  for (final image in (json['images'] as List).cast<Map<String, dynamic>>()) {
    final file = image['filename'] as String?;
    if (file == null) continue;
    final size = double.parse((image['size'] as String).split('x').first);
    final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
    found[file] = (size * scale).round();
  }
  return [for (final entry in found.entries) (file: entry.key, pixels: entry.value)];
}

Future<Uint8List> renderRgb(int size) async {
  final recorder = ui.PictureRecorder();
  const CatIconPainter().paint(ui.Canvas(recorder), Size(size.toDouble(), size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final rgba = (await image.toByteData())!.buffer.asUint8List();
  final rgb = Uint8List(size * size * 3);
  for (var i = 0; i < size * size; i++) {
    rgb[i * 3] = rgba[i * 4];
    rgb[i * 3 + 1] = rgba[i * 4 + 1];
    rgb[i * 3 + 2] = rgba[i * 4 + 2];
  }
  return rgb;
}

void main() {
  group('the PNG writer', () {
    test('writes the PNG signature, then a header chunk, with no alpha channel', () {
      final png = encodeRgbPng(2, 2, Uint8List.fromList(List.filled(12, 200)));
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
      final data = ByteData.sublistView(png);
      expect(data.getUint32(16), 2);
      expect(data.getUint32(20), 2);
      expect(png[24], 8, reason: 'bits per colour');
      expect(png[25], 2, reason: 'colour type 2 means no alpha');
    });

    test('ends with an IEND chunk', () {
      final png = encodeRgbPng(1, 1, Uint8List.fromList([1, 2, 3]));
      expect(String.fromCharCodes(png.sublist(png.length - 8, png.length - 4)), 'IEND');
    });

    test('checksums match the known value for the standard test text', () {
      expect(crc32('123456789'.codeUnits), 0xCBF43926);
      expect(crc32(const []), 0);
    });

    test('rejects the wrong amount of colour data', () {
      expect(() => encodeRgbPng(2, 2, Uint8List(5)), throwsArgumentError);
    });

    test('a picture reads back the same: the compressed data inflates to the rows we wrote', () {
      final rgb = Uint8List.fromList([for (var i = 0; i < 4 * 3 * 3; i++) i * 7 % 256]);
      final png = encodeRgbPng(4, 3, rgb);
      // Find the IDAT chunk and inflate it.
      var offset = 8;
      Uint8List? idat;
      while (offset < png.length) {
        final length = ByteData.sublistView(png).getUint32(offset);
        final type = String.fromCharCodes(png.sublist(offset + 4, offset + 8));
        if (type == 'IDAT') idat = png.sublist(offset + 8, offset + 8 + length);
        offset += 12 + length;
      }
      final raw = Uint8List.fromList(ZLibCodec().decode(idat!));
      expect(raw.length, 3 * (1 + 4 * 3));
      for (var y = 0; y < 3; y++) {
        expect(raw[y * 13], 0, reason: 'filter byte of row $y');
        expect(raw.sublist(y * 13 + 1, y * 13 + 13), rgb.sublist(y * 12, y * 12 + 12));
      }
    });
  });

  group('the iPhone app icon', () {
    final icons = requiredIcons();

    test('the project lists the icon sizes it needs, including the 1024-pixel one', () {
      expect(icons.length, greaterThanOrEqualTo(15));
      expect(icons.map((i) => i.pixels), contains(1024));
    });

    test('every icon file exists, has the right size, and has no transparency', () {
      for (final icon in icons) {
        final file = File('$iconFolder/${icon.file}');
        expect(file.existsSync(), isTrue, reason: icon.file);
        final bytes = file.readAsBytesSync();
        final data = ByteData.sublistView(bytes);
        expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10], reason: icon.file);
        expect(data.getUint32(16), icon.pixels, reason: '${icon.file} width');
        expect(data.getUint32(20), icon.pixels, reason: '${icon.file} height');
        expect(bytes[25], 2, reason: '${icon.file} has an alpha channel, which iPhone icons may not');
      }
    });
  });

  // Run once with  CATCLOCK_WRITE_ICONS=1  to (re)make the iPhone icon files.
  testWidgets('writes the iPhone icon files when asked to', (tester) async {
    if (Platform.environment['CATCLOCK_WRITE_ICONS'] != '1') return;
    await tester.runAsync(() async {
      for (final icon in requiredIcons()) {
        final rgb = await renderRgb(icon.pixels);
        File('$iconFolder/${icon.file}').writeAsBytesSync(encodeRgbPng(icon.pixels, icon.pixels, rgb));
      }
    });
  });
}
