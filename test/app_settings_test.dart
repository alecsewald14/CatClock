import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/app/app_settings.dart';
import 'package:cat_clock/storage/text_storage.dart';

void main() {
  test('defaults: the tray notice has not been seen', () {
    expect(const AppSettings().trayNoticeSeen, isFalse);
  });

  test('copyWith changes only what is named', () {
    expect(const AppSettings().copyWith(trayNoticeSeen: true).trayNoticeSeen, isTrue);
    expect(const AppSettings(trayNoticeSeen: true).copyWith().trayNoticeSeen, isTrue);
  });

  test('settings with the same values are equal', () {
    expect(const AppSettings(trayNoticeSeen: true), const AppSettings(trayNoticeSeen: true));
    expect(const AppSettings(), isNot(const AppSettings(trayNoticeSeen: true)));
  });

  test('loads the defaults when nothing was saved', () async {
    expect(await AppSettingsStore(MemoryTextStorage()).load(), const AppSettings());
  });

  test('loads back what was saved', () async {
    final storage = MemoryTextStorage();
    await AppSettingsStore(storage).save(const AppSettings(trayNoticeSeen: true));
    expect(await AppSettingsStore(storage).load(), const AppSettings(trayNoticeSeen: true));
  });

  test('falls back to the defaults for a damaged file', () async {
    for (final text in ['{{ nope', '[1]', '{"trayNoticeSeen": "yes"}', '']) {
      expect(await AppSettingsStore(MemoryTextStorage(text)).load(), const AppSettings(), reason: text);
    }
  });

  test('falls back to the defaults when the file cannot be read', () async {
    expect(await AppSettingsStore(BrokenReadStorage()).load(), const AppSettings());
  });

  test('a file with extra settings from a newer version still loads', () async {
    final storage = MemoryTextStorage('{"version": 9, "trayNoticeSeen": true, "newThing": 1}');
    expect(await AppSettingsStore(storage).load(), const AppSettings(trayNoticeSeen: true));
  });
}

class BrokenReadStorage implements TextStorage {
  @override
  Future<String?> read() async => throw StateError('cannot read');

  @override
  Future<void> write(String contents) async {}
}
