import 'dart:typed_data';

/// One picture inside an .ico file.
class IcoEntry {
  const IcoEntry({required this.size, required this.offset, required this.length});

  /// Width and height in pixels (icons are square here).
  final int size;

  /// Where the picture's bytes start in the file.
  final int offset;

  /// How many bytes the picture takes.
  final int length;
}

/// Builds a Windows .ico file from PNG pictures, one per size from 1 to 256 pixels.
///
/// Windows (Vista and later) accepts PNG pictures inside an .ico, which keeps small files
/// and full-colour, smooth-edged icons. The sizes are listed smallest first.
Uint8List buildIco(Map<int, Uint8List> pngBySize) {
  if (pngBySize.isEmpty) throw ArgumentError('Need at least one picture');
  final sizes = pngBySize.keys.toList()..sort();
  for (final size in sizes) {
    RangeError.checkValueInInterval(size, 1, 256, 'size');
  }

  const headerLength = 6;
  const entryLength = 16;
  var offset = headerLength + entryLength * sizes.length;

  final out = BytesBuilder();
  final header = ByteData(headerLength)
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // 1 means icon
    ..setUint16(4, sizes.length, Endian.little);
  out.add(header.buffer.asUint8List());

  for (final size in sizes) {
    final png = pngBySize[size]!;
    final entry = ByteData(entryLength)
      ..setUint8(0, size == 256 ? 0 : size) // 0 stands for 256
      ..setUint8(1, size == 256 ? 0 : size)
      ..setUint8(2, 0) // no colour palette
      ..setUint8(3, 0) // reserved
      ..setUint16(4, 1, Endian.little) // colour planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, png.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    out.add(entry.buffer.asUint8List());
    offset += png.length;
  }
  for (final size in sizes) {
    out.add(pngBySize[size]!);
  }
  return out.toBytes();
}

/// Reads the list of pictures in an .ico file. Throws a [FormatException] if the file is
/// not a valid icon.
List<IcoEntry> readIco(Uint8List bytes) {
  if (bytes.length < 6) throw const FormatException('Too short to be an icon');
  final data = ByteData.sublistView(bytes);
  if (data.getUint16(0, Endian.little) != 0 || data.getUint16(2, Endian.little) != 1) {
    throw const FormatException('Not an icon file');
  }
  final count = data.getUint16(4, Endian.little);
  if (bytes.length < 6 + 16 * count) throw const FormatException('The picture list is cut off');
  final entries = <IcoEntry>[];
  for (var i = 0; i < count; i++) {
    final base = 6 + 16 * i;
    final width = data.getUint8(base);
    entries.add(IcoEntry(
      size: width == 0 ? 256 : width,
      length: data.getUint32(base + 8, Endian.little),
      offset: data.getUint32(base + 12, Endian.little),
    ));
  }
  return entries;
}
