import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/storage/text_storage.dart';

void main() {
  group('MemoryTextStorage', () {
    test('starts empty and remembers what was written', () async {
      final storage = MemoryTextStorage();
      expect(await storage.read(), isNull);
      await storage.write('hello');
      expect(await storage.read(), 'hello');
    });

    test('can start with contents', () async {
      expect(await MemoryTextStorage('saved').read(), 'saved');
    });
  });

  group('FileTextStorage', () {
    late Directory folder;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('cat_clock_storage_test');
    });

    tearDown(() {
      folder.deleteSync(recursive: true);
    });

    test('reads null when the file does not exist yet', () async {
      final storage = FileTextStorage(File('${folder.path}/missing.json'));
      expect(await storage.read(), isNull);
    });

    test('writes and reads back text, including non-English characters', () async {
      final storage = FileTextStorage(File('${folder.path}/data.json'));
      await storage.write('{"name": "Müller ☀ 54°"}');
      expect(await storage.read(), '{"name": "Müller ☀ 54°"}');
    });

    test('replaces the old contents when written again', () async {
      final storage = FileTextStorage(File('${folder.path}/data.json'));
      await storage.write('a much longer first version of the text');
      await storage.write('short');
      expect(await storage.read(), 'short');
    });

    test('creates the folders on the way if they do not exist', () async {
      final file = File('${folder.path}/one/two/data.json');
      await FileTextStorage(file).write('x');
      expect(file.existsSync(), isTrue);
    });

    test('leaves no temporary file behind', () async {
      final storage = FileTextStorage(File('${folder.path}/data.json'));
      await storage.write('x');
      await storage.write('y');
      final names = folder.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names, ['data.json']);
    });

    test('an empty file reads as empty text, not null', () async {
      final file = File('${folder.path}/empty.json')..writeAsStringSync('');
      expect(await FileTextStorage(file).read(), '');
    });
  });
}
