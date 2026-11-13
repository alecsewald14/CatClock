import 'dart:io';

import 'win32_ffi.dart';

/// Makes sure only one copy of the app runs at a time, so two copies never ring the same
/// alarm. The first copy holds a lock on a small file; a second copy fails to get it.
class SingleInstance {
  SingleInstance._(this._file);

  // Kept open for as long as the app runs. The lock goes away when the app exits.
  // ignore: unused_field
  final RandomAccessFile _file;

  /// Takes the lock. Returns null if another copy of the app already holds it.
  static SingleInstance? acquire(Directory dataDirectory) {
    dataDirectory.createSync(recursive: true);
    final file = File('${dataDirectory.path}/instance.lock').openSync(mode: FileMode.write);
    try {
      file.lockSync(FileLock.exclusive);
      return SingleInstance._(file);
    } on FileSystemException {
      file.closeSync();
      return null;
    }
  }

  /// Asks the copy that is already running to come to the front.
  static void showTheRunningCopy() {
    Win32.bringRunningCopyToFront();
  }
}
