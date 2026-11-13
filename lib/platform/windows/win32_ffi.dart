import 'dart:ffi';
import 'dart:io' show pid;

import 'package:ffi/ffi.dart';

/// A few Windows calls the app needs and no package provides: finding its own window,
/// bringing it forward, and flashing its taskbar button.
///
/// They are looked up when first used and do nothing on other systems.
final class _FlashInfo extends Struct {
  @Uint32()
  external int cbSize;

  @IntPtr()
  external int hwnd;

  @Uint32()
  external int dwFlags;

  @Uint32()
  external int uCount;

  @Uint32()
  external int dwTimeout;
}

typedef _FindWindowExNative = IntPtr Function(
  IntPtr parent,
  IntPtr after,
  Pointer<Utf16> className,
  Pointer<Utf16> title,
);
typedef _FindWindowEx = int Function(
  int parent,
  int after,
  Pointer<Utf16> className,
  Pointer<Utf16> title,
);
typedef _ProcessOfNative = Uint32 Function(IntPtr hwnd, Pointer<Uint32> processId);
typedef _ProcessOf = int Function(int hwnd, Pointer<Uint32> processId);
typedef _ShowWindowNative = Int32 Function(IntPtr hwnd, Int32 command);
typedef _ShowWindow = int Function(int hwnd, int command);
typedef _SetForegroundNative = Int32 Function(IntPtr hwnd);
typedef _SetForeground = int Function(int hwnd);
typedef _FlashNative = Int32 Function(Pointer<_FlashInfo> info);
typedef _Flash = int Function(Pointer<_FlashInfo> info);

/// The class name the Flutter Windows runner gives its window (see windows/runner).
const String flutterWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

class Win32 {
  Win32._();

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final _FindWindowEx _findWindowEx =
      _user32.lookupFunction<_FindWindowExNative, _FindWindowEx>('FindWindowExW');
  static final _ProcessOf _processOf =
      _user32.lookupFunction<_ProcessOfNative, _ProcessOf>('GetWindowThreadProcessId');
  static final _ShowWindow _showWindow =
      _user32.lookupFunction<_ShowWindowNative, _ShowWindow>('ShowWindow');
  static final _SetForeground _setForeground =
      _user32.lookupFunction<_SetForegroundNative, _SetForeground>('SetForegroundWindow');
  static final _Flash _flash = _user32.lookupFunction<_FlashNative, _Flash>('FlashWindowEx');

  static int _processIdOf(int hwnd) {
    final out = calloc<Uint32>();
    try {
      _processOf(hwnd, out);
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  /// The handle of an app window, or 0 if there is none.
  ///
  /// A second copy of the app already has a window of its own by the time it starts
  /// running, so it passes [inAnotherProcess] to find the one that belongs to the copy
  /// that is already running.
  static int findAppWindow({bool inAnotherProcess = false}) {
    final className = flutterWindowClass.toNativeUtf16();
    try {
      var previous = 0;
      for (var i = 0; i < 20; i++) {
        final handle = _findWindowEx(0, previous, className, nullptr);
        if (handle == 0) return 0;
        if (!inAnotherProcess || _processIdOf(handle) != pid) return handle;
        previous = handle;
      }
      return 0;
    } finally {
      calloc.free(className);
    }
  }

  /// Shows and brings forward the window of the copy of the app that is already running.
  static bool bringRunningCopyToFront() {
    final handle = findAppWindow(inAnotherProcess: true);
    if (handle == 0) return false;
    const swRestore = 9;
    _showWindow(handle, swRestore);
    return _setForeground(handle) != 0;
  }

  /// Flashes this app's taskbar button until the window comes to the front.
  static bool flashTaskbar() {
    final handle = findAppWindow();
    if (handle == 0) return false;
    final info = calloc<_FlashInfo>();
    try {
      info.ref
        ..cbSize = sizeOf<_FlashInfo>()
        ..hwnd = handle
        ..dwFlags = 3 | 12 // flash the window and the taskbar button, until in front
        ..uCount = 0
        ..dwTimeout = 0;
      _flash(info);
      return true;
    } finally {
      calloc.free(info);
    }
  }
}
