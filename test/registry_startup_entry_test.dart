import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/platform/windows/registry_startup_entry.dart';

class Call {
  Call(this.executable, this.arguments);
  final String executable;
  final List<String> arguments;
}

class Runner {
  Runner({this.exitCode = 0});

  int exitCode;
  final List<Call> calls = [];

  Future<ProcessResult> call(String executable, List<String> arguments) async {
    calls.add(Call(executable, arguments));
    return ProcessResult(1, exitCode, '', exitCode == 0 ? '' : 'error text');
  }
}

const exe = r'C:\Program Files\Cat Clock\cat_clock.exe';

void main() {
  group('isEnabled', () {
    test('is true when the entry exists', () async {
      final runner = Runner(exitCode: 0);
      final entry = RegistryStartupEntry(executablePath: exe, run: runner.call);
      expect(await entry.isEnabled(), isTrue);
      expect(runner.calls.single.executable, 'reg');
      expect(runner.calls.single.arguments, [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'CatClock',
      ]);
    });

    test('is false when the entry is not there', () async {
      final entry = RegistryStartupEntry(executablePath: exe, run: Runner(exitCode: 1).call);
      expect(await entry.isEnabled(), isFalse);
    });
  });

  group('turning it on', () {
    test('adds one entry to the current user\'s start-up list that starts the app hidden', () async {
      final runner = Runner();
      final entry = RegistryStartupEntry(executablePath: exe, run: runner.call);
      await entry.setEnabled(true);
      expect(runner.calls.length, 1);
      expect(runner.calls.single.arguments, [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'CatClock',
        '/t',
        'REG_SZ',
        '/d',
        r'"C:\Program Files\Cat Clock\cat_clock.exe" --hidden',
        '/f',
      ]);
    });

    test('only ever touches the current user\'s list, never the whole machine', () async {
      final runner = Runner();
      final entry = RegistryStartupEntry(executablePath: exe, run: runner.call);
      await entry.setEnabled(true);
      await entry.setEnabled(false);
      await entry.isEnabled();
      for (final call in runner.calls) {
        final key = call.arguments[1];
        expect(key, startsWith(r'HKCU\'));
        expect(key, isNot(contains('HKLM')));
      }
    });

    test('reports a failure', () async {
      final entry = RegistryStartupEntry(executablePath: exe, run: Runner(exitCode: 5).call);
      expect(() => entry.setEnabled(true), throwsA(isA<ProcessException>()));
    });
  });

  group('turning it off', () {
    test('deletes the entry', () async {
      final runner = Runner();
      final entry = RegistryStartupEntry(executablePath: exe, run: runner.call);
      await entry.setEnabled(false);
      expect(runner.calls.single.arguments, [
        'delete',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'CatClock',
        '/f',
      ]);
    });

    test('is fine if the entry was not there (exit code 1)', () async {
      final entry = RegistryStartupEntry(executablePath: exe, run: Runner(exitCode: 1).call);
      await entry.setEnabled(false);
    });

    test('reports any other failure', () async {
      final entry = RegistryStartupEntry(executablePath: exe, run: Runner(exitCode: 5).call);
      expect(() => entry.setEnabled(false), throwsA(isA<ProcessException>()));
    });
  });

  // Talks to the real Windows registry, so it only runs when asked, and only ever touches a
  // scratch folder of its own, never the real start-up list:
  //   $env:CATCLOCK_TEST_REGISTRY = '1'; flutter test test/registry_startup_entry_test.dart
  test('works against the real registry in a scratch folder', () async {
    if (Platform.environment['CATCLOCK_TEST_REGISTRY'] != '1' || !Platform.isWindows) return;
    const scratchKey = r'HKCU\Software\CatClockTest';
    const spaced = r'C:\Program Files\Cat Clock With Spaces\cat_clock.exe';
    final entry = RegistryStartupEntry(
      executablePath: spaced,
      valueName: 'CatClockTest',
      keyPath: scratchKey,
    );
    try {
      expect(await entry.isEnabled(), isFalse);
      await entry.setEnabled(true);
      expect(await entry.isEnabled(), isTrue);

      // The stored command must be the quoted path, then the argument.
      final query = await Process.run('reg', ['query', scratchKey, '/v', 'CatClockTest']);
      expect('${query.stdout}', contains('"$spaced" --hidden'));

      await entry.setEnabled(false);
      expect(await entry.isEnabled(), isFalse);
      await entry.setEnabled(false); // turning off twice is fine
    } finally {
      await Process.run('reg', ['delete', scratchKey, '/f']);
    }
  });

  test('another entry name and folder can be used', () async {
    final runner = Runner();
    final entry = RegistryStartupEntry(
      executablePath: exe,
      valueName: 'Other',
      keyPath: r'HKCU\Software\SomethingElse',
      run: runner.call,
    );
    await entry.setEnabled(true);
    expect(runner.calls.single.arguments[1], r'HKCU\Software\SomethingElse');
    expect(runner.calls.single.arguments[3], 'Other');
  });
}
