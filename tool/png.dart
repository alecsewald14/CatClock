import 'dart:io';
import 'dart:typed_data';

/// A tiny PNG writer for pictures with no transparency at all: plain red, green, and blue,
/// with no alpha channel. iPhone app icons must be like that, and the picture library that
/// ships with Flutter always writes an alpha channel.
Uint8List encodeRgbPng(int width, int height, Uint8List rgb) {
  if (rgb.length != width * height * 3) {
    throw ArgumentError('Need exactly width * height * 3 bytes of colour');
  }

  // Each row starts with a filter byte; 0 means "none".
  final raw = Uint8List(height * (1 + width * 3));
  for (var y = 0; y < height; y++) {
    final out = y * (1 + width * 3);
    raw[out] = 0;
    raw.setRange(out + 1, out + 1 + width * 3, rgb, y * width * 3);
  }
  final compressed = Uint8List.fromList(ZLibCodec(level: 9).encode(raw));

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // 8 bits per colour
    ..setUint8(9, 2) // colour type 2: red, green, blue, no alpha
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final out = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(_chunk('IDAT', compressed))
    ..add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  final crcInput = Uint8List(typeBytes.length + data.length)
    ..setAll(0, typeBytes)
    ..setAll(typeBytes.length, data);
  final crc = ByteData(4)..setUint32(0, crc32(crcInput));
  return (BytesBuilder()
        ..add(length.buffer.asUint8List())
        ..add(typeBytes)
        ..add(data)
        ..add(crc.buffer.asUint8List()))
      .toBytes();
}

final List<int> _crcTable = () {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

/// The checksum PNG uses for each piece of the file.
int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
