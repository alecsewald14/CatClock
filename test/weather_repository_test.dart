import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/storage/text_storage.dart';
import 'package:cat_clock/weather/location_service.dart';
import 'package:cat_clock/weather/open_meteo_client.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_cache.dart';
import 'package:cat_clock/weather/weather_models.dart';
import 'package:cat_clock/weather/weather_problem.dart';
import 'package:cat_clock/weather/weather_repository.dart';
import 'package:cat_clock/weather/weather_rules.dart';

import 'helpers/weather_fakes.dart';

const found = LocationFound(40.7128, -74.0060);
const locationOff = LocationFailed(WeatherProblem.locationDisabled);
const noNetwork = WeatherFetchException(WeatherProblem.network, 'offline');

final start = DateTime.utc(2026, 11, 12, 15, 0);

class Harness {
  Harness({
    List<LocationResult>? location,
    List<Object>? outcomes,
    TextStorage? storage,
    TemperatureUnit unit = TemperatureUnit.fahrenheit,
  })  : clock = FakeClock(start),
        scheduler = FakeScheduler(),
        storage = storage ?? MemoryTextStorage() {
    this.location = FakeLocation(location ?? [found]);
    fetcher = FakeFetcher(outcomes ?? [snapshotAt(start)]);
    repo = WeatherRepository(
      location: this.location,
      fetcher: fetcher,
      cache: WeatherCache(this.storage),
      nowUtc: clock.call,
      unit: () => unit,
      scheduler: scheduler,
    );
    repo.addListener(() => notifications++);
  }

  final FakeClock clock;
  final FakeScheduler scheduler;
  final TextStorage storage;
  late final FakeLocation location;
  late final FakeFetcher fetcher;
  late final WeatherRepository repo;
  int notifications = 0;
}

void main() {
  group('starting', () {
    test('shows saved weather straight away, before the new fetch finishes', () async {
      final storage = MemoryTextStorage();
      await WeatherCache(storage).save(snapshotAt(start.subtract(const Duration(minutes: 10)), temperature: 40));
      final gate = Completer<WeatherSnapshot>();
      final h = Harness(storage: storage, outcomes: [gate]);

      final started = h.repo.start();
      await pumpEventQueue();
      expect(h.repo.snapshot?.now.temperature, 40, reason: 'saved weather is on screen');
      expect(h.repo.refreshing, isTrue);

      gate.complete(snapshotAt(start, temperature: 55));
      await started;
      expect(h.repo.snapshot?.now.temperature, 55);
      expect(h.repo.refreshing, isFalse);
    });

    test('fetches when nothing is saved, saves the result, and plans the next refresh in 15 minutes', () async {
      final h = Harness();
      await h.repo.start();
      expect(h.repo.snapshot, isNotNull);
      expect(h.repo.problem, isNull);
      expect(h.scheduler.pending, const Duration(minutes: 15));
      expect(await WeatherCache(h.storage).load(), isNotNull, reason: 'saved for next time');
    });

    test('passes the location and the temperature unit to the fetcher', () async {
      final h = Harness(unit: TemperatureUnit.celsius);
      await h.repo.start();
      final request = h.fetcher.requests.single;
      expect(request.latitude, 40.7128);
      expect(request.longitude, -74.0060);
      expect(request.unit, TemperatureUnit.celsius);
      expect(request.nowUtc, start);
    });

    test('ignores a damaged saved file and fetches normally', () async {
      final h = Harness(storage: MemoryTextStorage('garbage'));
      await h.repo.start();
      expect(h.repo.snapshot, isNotNull);
      expect(h.repo.problem, isNull);
    });
  });

  group('when something goes wrong', () {
    test('keeps the old weather and reports it when location is turned off', () async {
      final storage = MemoryTextStorage();
      await WeatherCache(storage).save(snapshotAt(start.subtract(const Duration(minutes: 5)), temperature: 47));
      final h = Harness(location: [locationOff], storage: storage);
      await h.repo.start();
      expect(h.repo.snapshot?.now.temperature, 47);
      expect(h.repo.problem, WeatherProblem.locationDisabled);
      expect(h.fetcher.requests, isEmpty, reason: 'no location, so nothing is sent');
    });

    test('reports denied permission', () async {
      final h = Harness(location: [const LocationFailed(WeatherProblem.locationDenied)]);
      await h.repo.start();
      expect(h.repo.problem, WeatherProblem.locationDenied);
      expect(h.repo.snapshot, isNull);
    });

    test('keeps the old weather and reports a network problem', () async {
      final storage = MemoryTextStorage();
      await WeatherCache(storage).save(snapshotAt(start.subtract(const Duration(minutes: 5)), temperature: 47));
      final h = Harness(outcomes: [noNetwork], storage: storage);
      await h.repo.start();
      expect(h.repo.snapshot?.now.temperature, 47);
      expect(h.repo.problem, WeatherProblem.network);
    });

    test('reports a bad response', () async {
      final h = Harness(outcomes: [const WeatherFetchException(WeatherProblem.badResponse, 'junk')]);
      await h.repo.start();
      expect(h.repo.problem, WeatherProblem.badResponse);
    });

    test('retries after 1, 2, 4, then 8 minutes, and keeps to 8', () async {
      final h = Harness(outcomes: [noNetwork]);
      await h.repo.start();
      for (var i = 0; i < 5; i++) {
        await h.scheduler.fire();
      }
      expect(h.scheduler.requested, [
        const Duration(minutes: 1),
        const Duration(minutes: 2),
        const Duration(minutes: 4),
        const Duration(minutes: 8),
        const Duration(minutes: 8),
        const Duration(minutes: 8),
      ]);
    });

    test('a success clears the problem and goes back to the 15-minute rhythm', () async {
      final h = Harness(outcomes: [noNetwork, noNetwork, snapshotAt(start)]);
      await h.repo.start();
      await h.scheduler.fire();
      expect(h.repo.problem, WeatherProblem.network);
      await h.scheduler.fire();
      expect(h.repo.problem, isNull);
      expect(h.scheduler.pending, const Duration(minutes: 15));
    });

    test('a failure after a success starts the retries from 1 minute again', () async {
      final h = Harness(outcomes: [snapshotAt(start), noNetwork, snapshotAt(start), noNetwork]);
      await h.repo.start();
      await h.scheduler.fire(); // fails
      await h.scheduler.fire(); // succeeds
      await h.scheduler.fire(); // fails again
      expect(h.scheduler.requested, [
        const Duration(minutes: 15),
        const Duration(minutes: 1),
        const Duration(minutes: 15),
        const Duration(minutes: 1),
      ]);
    });

    test('location failures are retried on the same schedule, so turning location on is noticed', () async {
      final h = Harness(location: [locationOff, locationOff, found]);
      await h.repo.start();
      await h.scheduler.fire();
      expect(h.repo.problem, WeatherProblem.locationDisabled);
      await h.scheduler.fire();
      expect(h.repo.problem, isNull);
      expect(h.repo.snapshot, isNotNull);
    });

    test('a failed save does not stop the weather from showing', () async {
      final h = Harness(storage: BrokenStorage());
      await h.repo.start();
      expect(h.repo.snapshot, isNotNull);
      expect(h.repo.problem, isNull);
    });
  });

  group('refreshing', () {
    test('later weather replaces earlier weather', () async {
      final h = Harness(outcomes: [snapshotAt(start, temperature: 50), snapshotAt(start, temperature: 52)]);
      await h.repo.start();
      expect(h.repo.snapshot?.now.temperature, 50);
      await h.scheduler.fire();
      expect(h.repo.snapshot?.now.temperature, 52);
    });

    test('a second refresh while one is running is ignored', () async {
      final gate = Completer<WeatherSnapshot>();
      final h = Harness(outcomes: [gate]);
      final first = h.repo.refresh();
      final second = h.repo.refresh();
      await pumpEventQueue();
      gate.complete(snapshotAt(start));
      await Future.wait([first, second]);
      expect(h.fetcher.requests.length, 1);
    });

    test('pausing cancels the timer, and resuming fetches again right away', () async {
      final h = Harness();
      await h.repo.start();
      expect(h.scheduler.pending, isNotNull);

      h.repo.pause();
      expect(h.scheduler.pending, isNull);

      await h.repo.resume();
      expect(h.fetcher.requests.length, 2);
      expect(h.scheduler.pending, const Duration(minutes: 15));
    });

    test('nothing is scheduled after a refresh that finishes while paused', () async {
      final gate = Completer<WeatherSnapshot>();
      final h = Harness(outcomes: [gate]);
      final started = h.repo.start();
      await pumpEventQueue();
      h.repo.pause();
      gate.complete(snapshotAt(start));
      await started;
      expect(h.scheduler.pending, isNull);
      expect(h.repo.snapshot, isNotNull, reason: 'the result is still kept');
    });
  });

  group('how fresh the weather is', () {
    test('follows the clock', () async {
      final h = Harness();
      await h.repo.start();
      expect(h.repo.freshness(), WeatherFreshness.fresh);
      h.clock.now = start.add(const Duration(minutes: 31));
      expect(h.repo.freshness(), WeatherFreshness.stale);
      h.clock.now = start.add(const Duration(hours: 3, minutes: 1));
      expect(h.repo.freshness(), WeatherFreshness.unavailable);
    });

    test('is unavailable when there is no weather at all', () async {
      final h = Harness(location: [locationOff]);
      await h.repo.start();
      expect(h.repo.freshness(), WeatherFreshness.unavailable);
    });

    test('saved weather that is already old is shown as unavailable', () async {
      final storage = MemoryTextStorage();
      await WeatherCache(storage).save(snapshotAt(start.subtract(const Duration(hours: 5))));
      final h = Harness(location: [locationOff], storage: storage);
      await h.repo.start();
      expect(h.repo.freshness(), WeatherFreshness.unavailable);
    });
  });

  group('listeners and cleanup', () {
    test('listeners hear about the start of a refresh and its result', () async {
      final h = Harness();
      await h.repo.start();
      expect(h.notifications, greaterThanOrEqualTo(2));
    });

    test('dispose cancels the timer', () async {
      final h = Harness();
      await h.repo.start();
      h.repo.dispose();
      expect(h.scheduler.pending, isNull);
    });

    test('a fetch that finishes after dispose is ignored quietly', () async {
      final gate = Completer<WeatherSnapshot>();
      final h = Harness(outcomes: [gate]);
      final started = h.repo.start();
      await pumpEventQueue();
      h.repo.dispose();
      gate.complete(snapshotAt(start));
      await started;
      expect(h.scheduler.pending, isNull);
    });
  });
}
