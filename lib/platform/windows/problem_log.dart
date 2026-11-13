import 'dart:io';

/// A small text file where the app writes down things that went wrong, so a problem can be
/// understood later. It never holds the person's location, alarm, or any personal detail.
///
/// The file is kept short: when it grows past [maxBytes], the oldest half is dropped.
class ProblemLog {
  ProblemLog(this.file, {this.maxBytes = 64 * 1024});

  final File file;
  final int maxBytes;

  void write(String message) {
    try {
      file.parent.createSync(recursive: true);
      final line = '${DateTime.now().toIso8601String()}  $message\n';
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);
      if (file.lengthSync() > maxBytes) {
        final text = file.readAsStringSync();
        final keep = text.substring(text.length ~/ 2);
        final firstLine = keep.indexOf('\n');
        file.writeAsStringSync(firstLine < 0 ? keep : keep.substring(firstLine + 1));
      }
    } catch (_) {
      // A log that cannot be written must never cause a problem of its own.
    }
  }
}
