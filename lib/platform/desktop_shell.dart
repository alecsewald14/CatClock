/// The parts of the computer's desktop the app talks to: its window, the tray icon, and
/// the taskbar. Windows has a real one; tests use a fake.
abstract interface class DesktopShell {
  /// Sets up the window and the tray icon.
  ///
  /// [onCloseRequested] runs when the person closes the window; the window is hidden to the
  /// tray afterwards. [onQuitRequested] runs when they choose Quit in the tray menu; the app
  /// decides whether to go ahead (and then calls [quit]). With [startHidden] the window
  /// stays hidden until the person opens it from the tray.
  Future<void> start({
    required Future<void> Function() onCloseRequested,
    required Future<void> Function() onQuitRequested,
    required bool startHidden,
  });

  /// Brings the window to the front, restoring it if it was minimized or hidden.
  Future<void> showWindow();

  /// Gets the person's attention: brings the window forward and flashes the taskbar.
  Future<void> alertUser();

  /// Closes the app for good.
  Future<void> quit();
}
