import 'dart:async';

/// Simple debouncer utility used by the document editor for auto-save and
/// similar behaviours. Wraps a [Timer] and ensures only the latest scheduled
/// callback fires.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
