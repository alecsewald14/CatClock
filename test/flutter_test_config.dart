import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests normally draw all text as plain squares. This loads the Roboto font that comes
/// with Flutter, so saved test images show real letters and can be checked by eye.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRoboto();
  await testMain();
}

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final folder = '$root/bin/cache/artifacts/material_fonts';
  final files = <String, String>{
    'roboto-regular.ttf': 'Roboto',
    'roboto-bold.ttf': 'Roboto',
  };
  final loader = FontLoader('Roboto');
  var found = false;
  for (final name in files.keys) {
    final file = File('$folder/$name');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      found = true;
    }
  }
  if (found) await loader.load();

  // The icon font, so the alarm bell draws as a bell and not an empty box.
  final icons = File('$folder/materialicons-regular.otf');
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await iconLoader.load();
  }
}
