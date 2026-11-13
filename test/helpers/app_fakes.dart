import 'package:cat_clock/platform/desktop_shell.dart';
import 'package:cat_clock/platform/startup_entry.dart';

/// A window shell that writes down what it was asked, and lets a test act as the person
/// closing the window or choosing Quit in the tray.
class FakeShell implements DesktopShell {
  Future<void> Function()? _onCloseRequested;
  Future<void> Function()? _onQuitRequested;
  bool? startedHidden;
  int showCount = 0;
  int alertCount = 0;
  int quitCount = 0;
  int startCount = 0;

  @override
  Future<void> start({
    required Future<void> Function() onCloseRequested,
    required Future<void> Function() onQuitRequested,
    required bool startHidden,
  }) async {
    startCount++;
    _onCloseRequested = onCloseRequested;
    _onQuitRequested = onQuitRequested;
    startedHidden = startHidden;
  }

  /// Acts as the person clicking the window's close button.
  Future<void> requestClose() async => _onCloseRequested!();

  /// Acts as the person choosing Quit from the tray menu.
  Future<void> requestQuit() async => _onQuitRequested!();

  @override
  Future<void> showWindow() async => showCount++;

  @override
  Future<void> alertUser() async => alertCount++;

  @override
  Future<void> quit() async => quitCount++;
}

/// A start-up entry kept in memory.
class FakeStartupEntry implements StartupEntry {
  FakeStartupEntry({this.enabled = false});

  bool enabled;
  bool failNextChange = false;
  bool failToRead = false;
  final List<bool> changes = [];

  @override
  Future<bool> isEnabled() async {
    if (failToRead) throw StateError('cannot read');
    return enabled;
  }

  @override
  Future<void> setEnabled(bool value) async {
    changes.add(value);
    if (failNextChange) {
      failNextChange = false;
      throw StateError('cannot change');
    }
    enabled = value;
  }
}
