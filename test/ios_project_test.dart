import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/platform/ios/alarmkit_api.dart';
import 'package:cat_clock/platform/signature_info.dart';

/// The iPhone side is Swift and cannot run here, so these tests check the things that can
/// go wrong between the Dart code and the Swift file and project settings.
void main() {
  final swift = File('ios/Runner/AlarmBridge.swift').readAsStringSync();
  final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final info = File('ios/Runner/Info.plist').readAsStringSync();
  final dart = File('lib/platform/ios/alarmkit_api.dart').readAsStringSync();

  group('Dart and Swift agree', () {
    test('on the channel names', () {
      expect(swift, contains('"$alarmKitChannelName"'));
      expect(swift, contains('"$alarmKitEventsName"'));
      expect(swift, contains('"$signatureChannelName"'));
    });

    test('on every method Dart calls', () {
      final methods = RegExp(r"invoke(?:List)?Method(?:<[^>]*>)?\('(\w+)'").allMatches(dart).map((m) => m.group(1)!).toSet();
      expect(methods, containsAll(['permission', 'requestPermission', 'schedule', 'cancelAll', 'stopAll', 'snoozeAll', 'current']));
      for (final method in methods) {
        expect(swift, contains('case "$method"'), reason: 'Swift does not handle "$method"');
      }
      expect(File('lib/platform/signature_info.dart').readAsStringSync(), contains("'expiresAt'"));
      expect(swift, contains('"expiresAt"'));
    });

    test('on the names of alarm states and permissions', () {
      for (final state in SystemAlarmState.values) {
        expect(swift, contains('return "${state.name}"'), reason: 'state ${state.name}');
      }
      for (final permission in AlarmPermission.values) {
        expect(swift, contains('return "${permission.name}"'), reason: 'permission ${permission.name}');
      }
    });

    test('on the names of the settings sent with "schedule"', () {
      for (final key in ['hour', 'minute', 'repeatDaily', 'soundFile', 'snoozeSeconds']) {
        expect(dart, contains("'$key'"), reason: 'Dart sends $key');
        expect(swift, contains('arguments["$key"]'), reason: 'Swift reads $key');
      }
    });
  });

  group('the app is wired up', () {
    test('the bridge is registered when the engine starts', () {
      expect(appDelegate, contains('AlarmBridge()'));
      expect(appDelegate, contains('alarmBridge.register'));
    });

    test('the Swift file is part of the app target, so it is really compiled', () {
      expect(RegExp('AlarmBridge.swift in Sources').allMatches(project).length, 2,
          reason: 'one build-file entry and one in the Sources list');
      expect(project, contains('path = AlarmBridge.swift'));
    });

    test('the minimum iOS version is 26 everywhere, which AlarmKit needs', () {
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);').allMatches(project).map((m) => m.group(1));
      expect(targets, isNotEmpty);
      expect(targets.toSet(), {'26.0'});
    });

    test('the alarm and location permission questions explain themselves', () {
      for (final key in ['NSAlarmKitUsageDescription', 'NSLocationWhenInUseUsageDescription']) {
        final match = RegExp('<key>$key</key>\\s*<string>([^<]+)</string>').firstMatch(info);
        expect(match, isNotNull, reason: key);
        expect(match!.group(1)!.length, greaterThan(40), reason: '$key should be a real sentence');
      }
    });

    test('the app is named Cat Clock', () {
      expect(RegExp(r'<key>CFBundleDisplayName</key>\s*<string>Cat Clock</string>').hasMatch(info), isTrue);
    });
  });

  group('the Swift code', () {
    test('uses the iOS 26.1 alert form only where it exists', () {
      expect(swift, contains('#available(iOS 26.1, *)'));
    });

    test('asks for the loudness file by the name Dart gives it, from the app itself', () {
      expect(swift, contains('.named(soundFile)'));
    });

    test('repeats every day by listing all seven weekdays', () {
      for (final day in ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']) {
        expect(swift, contains('.$day'), reason: day);
      }
    });

    test('reads the signature expiry from the embedded profile', () {
      expect(swift, contains('embedded'));
      expect(swift, contains('ExpirationDate'));
    });
  });
}
