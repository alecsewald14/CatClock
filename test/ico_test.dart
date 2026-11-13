import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/ico.dart';

/// The first 8 bytes of every PNG file.
const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// A pretend PNG: the real signature, the width and height where a real header keeps them,
/// then filler. Enough to test the file layout.
Uint8List fakePng(int size, {int extra = 10}) {
  final bytes = Uint8List(24 + extra);
  bytes.setAll(0, pngSignature);
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, size);
  data.setUint32(20, size);
  return bytes;
}

void main() {
  group('buildIco', () {
    test('writes a header that says: an icon file with this many pictures', () {
      final ico = buildIco({16: fakePng(16), 32: fakePng(32)});
      final data = ByteData.sublistView(ico);
      expect(data.getUint16(0, Endian.little), 0);
      expect(data.getUint16(2, Endian.little), 1);
      expect(data.getUint16(4, Endian.little), 2);
    });

    test('lists the pictures smallest first, whatever order they were given in', () {
      final ico = buildIco({256: fakePng(256), 16: fakePng(16), 48: fakePng(48)});
      expect(readIco(ico).map((e) => e.size), [16, 48, 256]);
    });

    test('stores 256 as 0 in the size byte, as the format requires', () {
      final ico = buildIco({256: fakePng(256)});
      expect(ico[6], 0);
      expect(ico[7], 0);
      expect(readIco(ico).single.size, 256);
    });

    test('says each picture is 32-bit colour with one plane', () {
      final ico = buildIco({32: fakePng(32)});
      final data = ByteData.sublistView(ico);
      expect(data.getUint16(6 + 4, Endian.little), 1);
      expect(data.getUint16(6 + 6, Endian.little), 32);
    });

    test('each picture starts where its entry says, with the PNG signature', () {
      final pictures = {16: fakePng(16, extra: 5), 32: fakePng(32, extra: 50), 64: fakePng(64, extra: 500)};
      final ico = buildIco(pictures);
      for (final entry in readIco(ico)) {
        expect(ico.sublist(entry.offset, entry.offset + 8), pngSignature, reason: '${entry.size}');
        expect(entry.length, pictures[entry.size]!.length, reason: '${entry.size}');
        expect(ico.sublist(entry.offset, entry.offset + entry.length), pictures[entry.size]);
      }
    });

    test('pictures follow one another with no gaps, and the file ends where the last ends', () {
      final ico = buildIco({16: fakePng(16), 32: fakePng(32, extra: 99), 48: fakePng(48, extra: 7)});
      final entries = readIco(ico);
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i].offset, entries[i - 1].offset + entries[i - 1].length);
      }
      expect(ico.length, entries.last.offset + entries.last.length);
    });

    test('rejects an empty set and sizes that are not allowed', () {
      expect(() => buildIco({}), throwsArgumentError);
      expect(() => buildIco({0: fakePng(1)}), throwsRangeError);
      expect(() => buildIco({257: fakePng(1)}), throwsRangeError);
    });
  });

  group('readIco', () {
    test('rejects text that is not an icon', () {
      expect(() => readIco(Uint8List.fromList([1, 2, 3])), throwsFormatException);
      expect(() => readIco(Uint8List.fromList(List.filled(40, 7))), throwsFormatException);
    });

    test('rejects an icon whose picture list is cut off', () {
      final ico = buildIco({16: fakePng(16), 32: fakePng(32)});
      expect(() => readIco(ico.sublist(0, 20)), throwsFormatException);
    });
  });

  group('the icon the app really uses', () {
    final file = File('windows/runner/resources/app_icon.ico');

    test('exists', () {
      expect(file.existsSync(), isTrue);
    });

    test('holds all seven sizes Windows asks for', () {
      final entries = readIco(file.readAsBytesSync());
      expect(entries.map((e) => e.size), [16, 24, 32, 48, 64, 128, 256]);
    });

    test('has a real PNG of the right size for each entry', () {
      final bytes = file.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      for (final entry in readIco(bytes)) {
        expect(bytes.sublist(entry.offset, entry.offset + 8), pngSignature, reason: '${entry.size}');
        // A PNG keeps its width and height right after the signature and chunk header.
        expect(data.getUint32(entry.offset + 16), entry.size, reason: 'width of ${entry.size}');
        expect(data.getUint32(entry.offset + 20), entry.size, reason: 'height of ${entry.size}');
      }
    });

    test('is a sensible size on disk', () {
      expect(file.lengthSync(), inInclusiveRange(10 * 1024, 400 * 1024));
    });
  });
}
