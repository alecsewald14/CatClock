import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/storage/text_storage.dart';
import 'package:cat_clock/weather/weather_cache.dart';

import 'helpers/weather_fakes.dart';

void main() {
  final fetched = DateTime.utc(2026, 11, 12, 15, 30);

  test('loads nothing when nothing has been saved', () async {
    final cache = WeatherCache(MemoryTextStorage());
    expect(await cache.load(), isNull);
    expect(cache.lastLoadProblem, isNull);
  });

  test('loads back what was saved', () async {
    final storage = MemoryTextStorage();
    await WeatherCache(storage).save(snapshotAt(fetched, temperature: 61));
    final loaded = await WeatherCache(storage).load();
    expect(loaded, isNotNull);
    expect(loaded!.fetchedAtUtc, fetched);
    expect(loaded.now.temperature, 61);
    expect(loaded.nextHours.length, 6);
    expect(loaded.latitude, 40.71);
  });

  test('writes a version number so the format can change later', () async {
    final storage = MemoryTextStorage();
    await WeatherCache(storage).save(snapshotAt(fetched));
    final decoded = jsonDecode(storage.contents!) as Map<String, dynamic>;
    expect(decoded['version'], 1);
    expect(decoded['snapshot'], isA<Map>());
  });

  test('treats text that is not JSON as nothing saved, and says why', () async {
    final cache = WeatherCache(MemoryTextStorage('{{ not json'));
    expect(await cache.load(), isNull);
    expect(cache.lastLoadProblem, isNotNull);
  });

  test('treats a damaged snapshot as nothing saved', () async {
    final cache = WeatherCache(MemoryTextStorage('{"version":1,"snapshot":{"x":1}}'));
    expect(await cache.load(), isNull);
    expect(cache.lastLoadProblem, isNotNull);
  });

  test('ignores a file from a newer version of the app', () async {
    final storage = MemoryTextStorage();
    await WeatherCache(storage).save(snapshotAt(fetched));
    final decoded = jsonDecode(storage.contents!) as Map<String, dynamic>;
    decoded['version'] = 99;
    final cache = WeatherCache(MemoryTextStorage(jsonEncode(decoded)));
    expect(await cache.load(), isNull);
    expect(cache.lastLoadProblem, contains('version'));
  });

  test('a saved file holds only the rounded coordinates and weather, nothing else', () async {
    final storage = MemoryTextStorage();
    await WeatherCache(storage).save(snapshotAt(fetched));
    final decoded = jsonDecode(storage.contents!) as Map<String, dynamic>;
    final snapshot = decoded['snapshot'] as Map<String, dynamic>;
    expect(snapshot.keys.toSet(), {'fetchedAtUtc', 'latitude', 'longitude', 'unit', 'now', 'nextHours'});
  });
}
