import 'dart:async';
import 'package:flutter/foundation.dart';
import 'screen_wake.dart';

enum NapPhase { idle, running, done }

class NapTimerService extends ChangeNotifier {
  /// The four durations Brooks & Lack (2006) compared head-to-head, so each
  /// preset can state what that specific length actually did in the study
  /// rather than offering round numbers with no evidence behind them.
  static const presets = [5, 10, 20, 30];
  static const recommendedMinutes = 10;
  static const snoozeSeconds = 180;

  int minutes = recommendedMinutes;
  int totalSeconds = recommendedMinutes * 60;
  int remainingSeconds = recommendedMinutes * 60;
  NapPhase phase = NapPhase.idle;
  bool alarmFiring = false;
  Timer? _timer;
  static const _wakeKey = 'nap';

  void selectPreset(int m) {
    if (phase == NapPhase.running) return;
    minutes = m;
    totalSeconds = m * 60;
    remainingSeconds = totalSeconds;
    notifyListeners();
  }

  void start() {
    _timer?.cancel();
    ScreenWake.acquire(_wakeKey);
    phase = NapPhase.running;
    alarmFiring = false;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        remainingSeconds = 0;
        _finish();
      }
      notifyListeners();
    });
  }

  void _finish() {
    _timer?.cancel();
    // Hold the screen through the alarm — releasing here would let it
    // sleep while the thing is still ringing. cancel() does the release.
    phase = NapPhase.done;
    alarmFiring = true;
    notifyListeners();
  }

  void snooze() {
    _timer?.cancel();
    ScreenWake.acquire(_wakeKey);
    minutes = (snoozeSeconds / 60).ceil();
    totalSeconds = snoozeSeconds;
    remainingSeconds = snoozeSeconds;
    phase = NapPhase.running;
    alarmFiring = false;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        remainingSeconds = 0;
        _finish();
      }
      notifyListeners();
    });
  }

  void cancel() {
    _timer?.cancel();
    ScreenWake.release(_wakeKey);
    phase = NapPhase.idle;
    alarmFiring = false;
    remainingSeconds = totalSeconds;
    notifyListeners();
  }

  double get fraction =>
      totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds;

  String get formatted {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
