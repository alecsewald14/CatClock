import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'location_service.dart';
import 'open_meteo_client.dart';
import 'refresh_scheduler.dart';
import 'units.dart';
import 'weather_cache.dart';
import 'weather_models.dart';
import 'weather_problem.dart';
import 'weather_rules.dart';

/// Keeps the weather up to date and remembers the last good result.
///
/// * At start-up it shows the saved weather at once, then fetches new weather.
/// * It refreshes every 15 minutes while the app is on screen, and straight away when the
///   app comes back to the screen.
/// * When something goes wrong (no location, no network), the last good weather stays on
///   screen and [problem] says why. It tries again after 1, 2, 4, then every 8 minutes,
///   so it recovers soon after the problem is fixed.
///
/// The clock and the alarm never depend on this class.
class WeatherRepository extends ChangeNotifier {
  WeatherRepository({
    required this._location,
    required this._fetcher,
    required this._cache,
    required this._nowUtc,
    required this._unit,
    required this._scheduler,
    this.refreshEvery = const Duration(minutes: 15),
    this.retryDelays = const [
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 4),
      Duration(minutes: 8),
    ],
  });

  /// How often to refresh when all is well.
  final Duration refreshEvery;

  /// How long to wait before each retry after a failure. The last one repeats.
  final List<Duration> retryDelays;

  final LocationService _location;
  final WeatherFetcher _fetcher;
  final WeatherCache _cache;
  final DateTime Function() _nowUtc;
  final TemperatureUnit Function() _unit;
  final RefreshScheduler _scheduler;

  WeatherSnapshot? _snapshot;
  WeatherProblem? _problem;
  bool _refreshing = false;
  bool _running = false;
  bool _disposed = false;
  int _failures = 0;

  /// The last good weather, or null if there has never been any.
  WeatherSnapshot? get snapshot => _snapshot;

  /// Why the latest attempt failed, or null if it went fine.
  WeatherProblem? get problem => _problem;

  /// True while a refresh is under way.
  bool get refreshing => _refreshing;

  /// How trustworthy the weather is right now.
  WeatherFreshness freshness() => freshnessOf(_snapshot?.fetchedAtUtc, _nowUtc());

  /// Shows the saved weather, then fetches new weather and keeps it up to date.
  Future<void> start() async {
    _running = true;
    final saved = await _cache.load();
    if (_disposed) return;
    if (saved != null && _snapshot == null) {
      _snapshot = saved;
      notifyListeners();
    }
    await refresh();
  }

  /// Stops refreshing. Call when the app is hidden or minimized.
  void pause() {
    _running = false;
    _scheduler.cancel();
  }

  /// Refreshes at once and starts the regular refreshing again. Call when the app comes
  /// back to the screen.
  Future<void> resume() async {
    _running = true;
    await refresh();
  }

  /// Fetches new weather now. Does nothing if a refresh is already under way.
  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    _scheduler.cancel();
    notifyListeners();
    try {
      await _refreshOnce();
    } finally {
      _refreshing = false;
      if (!_disposed) {
        _scheduleNext();
        notifyListeners();
      }
    }
  }

  Future<void> _refreshOnce() async {
    LocationResult where;
    try {
      where = await _location.current();
    } catch (error) {
      where = LocationFailed(WeatherProblem.locationUnavailable, '$error');
    }
    if (_disposed) return;

    switch (where) {
      case LocationFailed(:final problem):
        _problem = problem;
        _failures++;
      case LocationFound(:final latitude, :final longitude):
        try {
          final fresh = await _fetcher.fetch(
            latitude: latitude,
            longitude: longitude,
            unit: _unit(),
            nowUtc: _nowUtc(),
          );
          if (_disposed) return;
          _snapshot = fresh;
          _problem = null;
          _failures = 0;
          try {
            await _cache.save(fresh);
          } catch (_) {
            // Not being able to save is not worth losing the weather over.
          }
        } on WeatherFetchException catch (error) {
          if (_disposed) return;
          _problem = error.problem;
          _failures++;
        } catch (_) {
          if (_disposed) return;
          _problem = WeatherProblem.network;
          _failures++;
        }
    }
  }

  void _scheduleNext() {
    if (!_running || _disposed) return;
    final delay = _failures == 0
        ? refreshEvery
        : retryDelays[math.min(_failures - 1, retryDelays.length - 1)];
    _scheduler.scheduleOnce(delay, () {
      refresh();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _scheduler.cancel();
    super.dispose();
  }
}
