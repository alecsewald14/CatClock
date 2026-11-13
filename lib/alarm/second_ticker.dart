import 'dart:async';

/// Calls something once a second. A thin wrapper around a timer, so tests can tick by hand.
abstract interface class SecondTicker {
  void start(void Function() onTick);
  void stop();
}

class TimerSecondTicker implements SecondTicker {
  Timer? _timer;

  @override
  void start(void Function() onTick) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
