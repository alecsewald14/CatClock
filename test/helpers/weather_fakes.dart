import 'dart:async';

import 'package:cat_clock/storage/text_storage.dart';
import 'package:cat_clock/weather/location_service.dart';
import 'package:cat_clock/weather/open_meteo_client.dart';
import 'package:cat_clock/weather/refresh_scheduler.dart';
import 'package:cat_clock/weather/units.dart';
import 'package:cat_clock/weather/weather_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A weather result fetched at [fetchedAtUtc], with six hours after it.
WeatherSnapshot snapshotAt(
  DateTime fetchedAtUtc, {
  double temperature = 54,
  TemperatureUnit unit = TemperatureUnit.fahrenheit,
  double latitude = 40.71,
  double longitude = -74.01,
}) {
  return WeatherSnapshot(
    fetchedAtUtc: fetchedAtUtc,
    latitude: latitude,
    longitude: longitude,
    unit: unit,
    now: WeatherNow(temperature: temperature, code: 2, isDay: true),
    nextHours: [
      for (var i = 1; i <= 6; i++)
        HourWeather(
          time: DateTime(2026, 11, 12, 12 + i),
          temperature: temperature - i,
          code: 3,
          isDay: true,
        ),
    ],
  );
}

/// Hands out the location results it was given, one per call (the last one repeats).
class FakeLocation implements LocationService {
  FakeLocation(this.results);

  final List<LocationResult> results;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    final result = results[calls < results.length ? calls : results.length - 1];
    calls++;
    return result;
  }
}

/// One request the fake fetcher received.
class Request {
  Request(this.latitude, this.longitude, this.unit, this.nowUtc);
  final double latitude;
  final double longitude;
  final TemperatureUnit unit;
  final DateTime nowUtc;
}

/// Hands out the outcomes it was given, one per call (the last one repeats).
/// An outcome is a [WeatherSnapshot] (success), a [WeatherFetchException] (failure), or a
/// [Completer] the test finishes later.
class FakeFetcher implements WeatherFetcher {
  FakeFetcher(this.outcomes);

  final List<Object> outcomes;
  final List<Request> requests = [];

  @override
  Future<WeatherSnapshot> fetch({
    required double latitude,
    required double longitude,
    required TemperatureUnit unit,
    required DateTime nowUtc,
  }) async {
    final index = requests.length < outcomes.length ? requests.length : outcomes.length - 1;
    requests.add(Request(latitude, longitude, unit, nowUtc));
    final outcome = outcomes[index];
    if (outcome is Completer<WeatherSnapshot>) return outcome.future;
    if (outcome is WeatherFetchException) throw outcome;
    return outcome as WeatherSnapshot;
  }
}

/// A timer the test fires by hand.
class FakeScheduler implements RefreshScheduler {
  final List<Duration> requested = [];
  Duration? pending;
  void Function()? _callback;

  @override
  void scheduleOnce(Duration delay, void Function() callback) {
    requested.add(delay);
    pending = delay;
    _callback = callback;
  }

  @override
  void cancel() {
    pending = null;
    _callback = null;
  }

  /// Fires the waiting timer, if there is one, and lets everything it starts finish.
  Future<void> fire() async {
    final callback = _callback;
    pending = null;
    _callback = null;
    callback?.call();
    await pumpEventQueue();
  }
}

/// A clock the test moves by hand.
class FakeClock {
  FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
}

/// Storage that fails when written to.
class BrokenStorage implements TextStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String contents) async => throw StateError('disk full');
}
