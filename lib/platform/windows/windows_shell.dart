// ignore_for_file: deprecated_member_use
// The window and tray packages keep their familiar API in a "legacy" library for now; it is
// the one used here.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../desktop_shell.dart';
import 'win32_ffi.dart';

/// The Windows window, tray icon, and taskbar.
///
/// Closing the window hides it to the tray so the alarm keeps working. If the tray icon
/// cannot be made, closing the window quits instead, so the app is never left running
/// where nobody can see it.
class WindowsDesktopShell with TrayListener, WindowListener implements DesktopShell {
  WindowsDesktopShell({this.log});

  /// Where to write down problems, such as a tray icon that could not be made.
  final void Function(String message)? log;

  late Future<void> Function() _onCloseRequested;
  late Future<void> Function() _onQuitRequested;
  bool _trayReady = false;
  Timer? _topmostTimer;

  static const _showKey = 'show';
  static const _quitKey = 'quit';
  static const _trayIconAsset = 'assets/icons/cat_tray.png';

  @override
  Future<void> start({
    required Future<void> Function() onCloseRequested,
    required Future<void> Function() onQuitRequested,
    required bool startHidden,
  }) async {
    _onCloseRequested = onCloseRequested;
    _onQuitRequested = onQuitRequested;

    await windowManager.ensureInitialized();
    // Small enough to fit a 1080-pixel-high screen even with Windows set to 150% scaling.
    const options = WindowOptions(
      size: Size(860, 640),
      minimumSize: Size(380, 600),
      center: true,
      title: 'Cat Clock',
      backgroundColor: Color(0xFF05070D),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (startHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    log?.call('Window ready. Prevent-close is ${await windowManager.isPreventClose()}.');

    await _setUpTray();
  }

  Future<void> _setUpTray() async {
    try {
      try {
        await trayManager.setIcon(_trayIconAsset);
      } catch (error) {
        log?.call('Tray icon from the asset name failed: $error');
        // Fall back to the file inside the installed app folder.
        final folder = File(Platform.resolvedExecutable).parent.path;
        await trayManager.setIcon('$folder/data/flutter_assets/$_trayIconAsset');
      }
      await trayManager.setToolTip('Cat Clock');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _showKey, label: 'Show Cat Clock'),
            MenuItem.separator(),
            MenuItem(key: _quitKey, label: 'Quit'),
          ],
        ),
      );
      trayManager.addListener(this);
      _trayReady = true;
      log?.call('Tray icon is ready.');
    } catch (error) {
      log?.call('The tray icon could not be made, so closing the window will quit: $error');
      _trayReady = false;
    }
  }

  // ---- Window events ----

  @override
  void onWindowClose() async {
    log?.call('Close requested. Tray ready: $_trayReady.');
    if (!_trayReady) {
      await quit();
      return;
    }
    await _onCloseRequested();
    await windowManager.hide();
  }

  // ---- Tray events ----

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case _showKey:
        await showWindow();
      case _quitKey:
        await showWindow();
        await _onQuitRequested();
    }
  }

  // ---- DesktopShell ----

  @override
  Future<void> showWindow() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> alertUser() async {
    await showWindow();
    // Windows does not always let a background app take the front, so also pulse the
    // window to the top for a moment and flash its taskbar button.
    await windowManager.setAlwaysOnTop(true);
    Win32.flashTaskbar();
    _topmostTimer?.cancel();
    _topmostTimer = Timer(const Duration(seconds: 5), () {
      windowManager.setAlwaysOnTop(false);
    });
  }

  @override
  Future<void> quit() async {
    _topmostTimer?.cancel();
    try {
      await trayManager.destroy();
    } catch (_) {
      // Closing anyway.
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    // If the window did not end the app, end it here.
    Timer(const Duration(seconds: 1), () => exit(0));
  }
}
