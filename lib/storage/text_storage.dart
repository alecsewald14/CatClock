import 'dart:io';

/// Somewhere to keep a small piece of text: the saved alarm, the saved weather.
/// The real app uses a file on the device; tests use [MemoryTextStorage].
abstract interface class TextStorage {
  /// The saved text, or null if nothing has been saved yet.
  Future<String?> read();

  Future<void> write(String contents);
}

/// Keeps the text in memory. Used in tests.
class MemoryTextStorage implements TextStorage {
  MemoryTextStorage([this.contents]);

  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async {
    this.contents = contents;
  }
}

/// Keeps the text in a file.
///
/// A save is written to a temporary file first and then moved over the real one, so a
/// power cut in the middle never leaves a half-written file.
class FileTextStorage implements TextStorage {
  FileTextStorage(this.file);

  final File file;

  @override
  Future<String?> read() async {
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String contents) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
