import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/platform/windows/registry_startup_entry.dart';

/// Checks on installer/CatClock.iss that matter to the person using the installer.
void main() {
  final script = File('installer/CatClock.iss').readAsStringSync();

  String define(String name) {
    final match = RegExp('^#define $name "([^"]*)"', multiLine: true).firstMatch(script);
    return match?.group(1) ?? '';
  }

  test('the installer version matches the app version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(define('AppVersion'), version);
  });

  test('installs for the current user only, with no administrator rights', () {
    expect(script, contains('PrivilegesRequired=lowest'));
    expect(script, isNot(contains('HKLM')));
    expect(script, isNot(contains('PrivilegesRequired=admin')));
  });

  test('installs the folder the Windows release build makes, and the program is cat_clock.exe', () {
    expect(define('SourceDir'), r'..\build\windows\x64\runner\Release');
    expect(define('AppExe'), 'cat_clock.exe');
  });

  test('uses the cat icon for the setup program and the uninstaller entry', () {
    expect(script, contains(r'SetupIconFile=..\windows\runner\resources\app_icon.ico'));
    expect(File('windows/runner/resources/app_icon.ico').existsSync(), isTrue);
    expect(script, contains(r'UninstallDisplayIcon={app}\{#AppExe}'));
  });

  test('adds a Start-menu shortcut, and a desktop one only if the person ticks it', () {
    expect(script, contains(r'Name: "{autoprograms}\{#AppName}"'));
    expect(script, contains('Name: "desktopicon"'));
    expect(script, contains('Flags: unchecked'));
  });

  test('uninstalling removes the "Start with Windows" entry the app creates', () {
    final entry = RegistryStartupEntry(executablePath: 'x');
    expect(script, contains('/v ${entry.valueName} /f'));
    expect(script, contains(entry.keyPath.replaceAll(r'HKCU\', '')));
    expect(script, contains('delete'));
  });

  test('stops the running app before installing and before uninstalling', () {
    expect(script, contains('taskkill.exe'));
    expect(script, contains('function PrepareToInstall'));
    expect(script, contains('function InitializeUninstall'));
  });

  test('never deletes the saved alarm and settings without asking, and defaults to keeping them', () {
    expect(script, contains('SuppressibleMsgBox'));
    expect(script, contains('MB_DEFBUTTON2, IDNO'));
    expect(script, contains(r'{userappdata}\app.catclock'));
  });

  test('the installer file name carries the version', () {
    expect(script, contains('OutputBaseFilename=CatClock-Setup-{#AppVersion}'));
  });
}
