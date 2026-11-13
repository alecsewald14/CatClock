import 'dart:async';

/// Calls something once after a delay. A thin wrapper around a timer, so tests can fire
/// it by hand.
abstract interface class RefreshScheduler {
  /// Replaces any waiting call with one that runs [callback] after [delay].
  void scheduleOnce(Duration delay, void Function() callback);

  /// Forgets the waiting call, if there is one.
  void cancel();
}

class TimerRefreshScheduler implements RefreshScheduler {
  Timer? _timer;

  @override
  void scheduleOnce(Duration delay, void Function() callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
