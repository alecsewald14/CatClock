import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_store.dart';
import 'package:cat_clock/storage/text_storage.dart';

void main() {
  group('Alarm', () {
    test('has sensible defaults: 7:00 AM, off, no repeat, level 3', () {
      const alarm = Alarm();
      expect(alarm.hour, 7);
      expect(alarm.minute, 0);
      expect(alarm.enabled, isFalse);
      expect(alarm.repeatDaily, isFalse);
      expect(alarm.soundId, 'soft_chime');
      expect(alarm.volumeLevel, 3);
    });

    test('copyWith changes only the named fields', () {
      const alarm = Alarm();
      final changed = alarm.copyWith(hour: 6, minute: 30, enabled: true);
      expect(changed.hour, 6);
      expect(changed.minute, 30);
      expect(changed.enabled, isTrue);
      expect(changed.soundId, alarm.soundId);
      expect(changed.volumeLevel, alarm.volumeLevel);
      expect(changed.repeatDaily, alarm.repeatDaily);
    });

    test('two alarms with the same values are equal', () {
      expect(const Alarm(hour: 6, minute: 30), const Alarm(hour: 6, minute: 30));
      expect(const Alarm(hour: 6), isNot(const Alarm(hour: 7)));
    });

    test('survives a trip through JSON', () {
      const alarm = Alarm(
        hour: 22,
        minute: 15,
        enabled: true,
        repeatDaily: true,
        soundId: 'cat_bell',
        volumeLevel: 5,
      );
      expect(Alarm.fromJson(alarm.toJson()), alarm);
    });

    test('fromJson rejects values that are out of range', () {
      Map<String, dynamic> withChange(String key, Object? value) {
        final json = const Alarm().toJson();
        json[key] = value;
        return json;
      }

      expect(() => Alarm.fromJson(withChange('hour', 24)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('hour', -1)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('minute', 60)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('volumeLevel', 0)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('volumeLevel', 6)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('soundId', '')), throwsFormatException);
    });

    test('fromJson rejects values of the wrong type', () {
      Map<String, dynamic> withChange(String key, Object? value) {
        final json = const Alarm().toJson();
        json[key] = value;
        return json;
      }

      expect(() => Alarm.fromJson(withChange('hour', '7')), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('enabled', 1)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('repeatDaily', null)), throwsFormatException);
      expect(() => Alarm.fromJson(withChange('soundId', 5)), throwsFormatException);
    });

    test('fromJson ignores keys it does not know', () {
      final json = const Alarm(hour: 8).toJson()..['somethingNew'] = 'ignored';
      expect(Alarm.fromJson(json), const Alarm(hour: 8));
    });
  });

  group('AlarmStore', () {
    test('loads the default alarm when nothing has been saved', () async {
      final store = AlarmStore(MemoryTextStorage());
      expect(await store.load(), const Alarm());
    });

    test('loads back what was saved', () async {
      final storage = MemoryTextStorage();
      const alarm = Alarm(hour: 6, minute: 45, enabled: true, repeatDaily: true);
      await AlarmStore(storage).save(alarm);
      expect(await AlarmStore(storage).load(), alarm);
    });

    test('writes a version number so the file format can change later', () async {
      final storage = MemoryTextStorage();
      await AlarmStore(storage).save(const Alarm());
      final decoded = jsonDecode(storage.contents!) as Map<String, dynamic>;
      expect(decoded['version'], 1);
    });

    test('falls back to the default alarm when the file is not valid JSON', () async {
      final storage = MemoryTextStorage('this is not json {{{');
      final store = AlarmStore(storage);
      expect(await store.load(), const Alarm());
      expect(store.lastLoadProblem, isNotNull);
    });

    test('falls back to the default alarm when the JSON is not an object', () async {
      final store = AlarmStore(MemoryTextStorage('[1, 2, 3]'));
      expect(await store.load(), const Alarm());
      expect(store.lastLoadProblem, isNotNull);
    });

    test('falls back to the default alarm when a value is out of range', () async {
      final json = jsonEncode({...const Alarm().toJson(), 'hour': 99, 'version': 1});
      final store = AlarmStore(MemoryTextStorage(json));
      expect(await store.load(), const Alarm());
      expect(store.lastLoadProblem, isNotNull);
    });

    test('reports no problem after a clean load', () async {
      final storage = MemoryTextStorage();
      final store = AlarmStore(storage);
      await store.save(const Alarm(hour: 9));
      await store.load();
      expect(store.lastLoadProblem, isNull);
    });
  });
}
