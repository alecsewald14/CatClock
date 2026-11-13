import 'dart:io';

import '../startup_entry.dart';

/// Runs a program and returns its result. Replaced in tests.
typedef CommandRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> _runForReal(String executable, List<String> arguments) {
  return Process.run(executable, arguments);
}

/// Starts the app when the person signs in to Windows, by adding or removing one entry
/// in their own list of start-up programs (`HKEY_CURRENT_USER`, so no administrator rights
/// are needed). The app then starts hidden in the tray, ready to ring.
class RegistryStartupEntry implements StartupEntry {
  RegistryStartupEntry({
    required this.executablePath,
    this.valueName = 'CatClock',
    this.keyPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
    CommandRunner? run,
  }) : _run = run ?? _runForReal;

  /// The full path of the app to start.
  final String executablePath;

  /// The name of the entry.
  final String valueName;

  /// The registry folder that holds the entry.
  final String keyPath;

  final CommandRunner _run;

  @override
  Future<bool> isEnabled() async {
    final result = await _run('reg', ['query', keyPath, '/v', valueName]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      final result = await _run('reg', [
        'add',
        keyPath,
        '/v',
        valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"$executablePath" --hidden',
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException('reg', ['add'], '${result.stderr}', result.exitCode);
      }
    } else {
      final result = await _run('reg', ['delete', keyPath, '/v', valueName, '/f']);
      // Exit code 1 means the entry was not there, which is just as good.
      if (result.exitCode != 0 && result.exitCode != 1) {
        throw ProcessException('reg', ['delete'], '${result.stderr}', result.exitCode);
      }
    }
  }
}
