import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

enum MicState { idle, starting, listening, denied }

/// Heuristic breathing-rhythm sensor: not a medical device, and it does not
/// try to isolate speech from breath. It watches the mic's decibel envelope
/// for a sustained, quiet, evenly-spaced peak rhythm (roughly 8–30 cycles a
/// minute — the plausible range for resting breathing/snoring) and treats a
/// long run of that as a sign the room has gone quiet and rhythmic, i.e.
/// someone nearby is asleep. Loud or irregular sound resets it immediately.
class BreathingDetector extends ChangeNotifier {
  static const _quietCeilingDb =
      62.0; // above this, treat as "not resting" noise
  static const _minPeakProminenceDb = 1.5;
  static const _minCycleSeconds = 2.0; // 30 breaths/min
  static const _maxCycleSeconds = 7.5; // 8 breaths/min
  static const _windowSeconds = 25;
  static const _requiredRegularCycles = 5;

  MicState state = MicState.idle;
  double currentDb = 0;
  double regularityScore = 0; // 0..1, how "breathing-like" the recent rhythm is
  Duration regularFor = Duration.zero;
  bool alarmFiring = false;
  Duration alarmThreshold = const Duration(seconds: 20);

  final List<_Sample> _samples = [];
  DateTime? _regularSince;
  DateTime? _suppressUntil;
  NoiseMeter? _meter;
  StreamSubscription<NoiseReading>? _sub;

  Future<void> start() async {
    state = MicState.starting;
    notifyListeners();
    final granted = await Permission.microphone.request();
    if (!granted.isGranted) {
      state = MicState.denied;
      notifyListeners();
      return;
    }
    try {
      _samples.clear();
      _regularSince = null;
      alarmFiring = false;
      _meter = NoiseMeter();
      _sub = _meter!.noise.listen(_onReading, onError: (_) {});
      state = MicState.listening;
    } catch (_) {
      state = MicState.denied;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _meter = null;
    state = MicState.idle;
    currentDb = 0;
    regularityScore = 0;
    regularFor = Duration.zero;
    alarmFiring = false;
    _samples.clear();
    notifyListeners();
  }

  void setThresholdSeconds(int seconds) {
    alarmThreshold = Duration(seconds: seconds);
  }

  void snooze() {
    alarmFiring = false;
    _regularSince = null;
    regularFor = Duration.zero;
    _suppressUntil = DateTime.now().add(const Duration(minutes: 3));
    notifyListeners();
  }

  void _onReading(NoiseReading reading) {
    final now = DateTime.now();
    currentDb = reading.meanDecibel.isFinite ? reading.meanDecibel : 0;
    _samples.add(_Sample(now, currentDb));
    final cutoff = now.subtract(const Duration(seconds: _windowSeconds));
    _samples.removeWhere((s) => s.time.isBefore(cutoff));

    final suppressed = _suppressUntil != null && now.isBefore(_suppressUntil!);
    if (suppressed || _samples.length < 10) {
      regularityScore = 0;
      notifyListeners();
      return;
    }

    if (currentDb > _quietCeilingDb) {
      // A loud or sudden sound means the room isn't in a resting state.
      regularityScore = 0;
      _regularSince = null;
      regularFor = Duration.zero;
      if (alarmFiring) alarmFiring = false;
      notifyListeners();
      return;
    }

    final peaks = _findPeaks();
    final regular = _isRegular(peaks);
    regularityScore = regular
        ? 1.0
        : (peaks.length / _requiredRegularCycles).clamp(0.0, 1.0);

    if (regular) {
      _regularSince ??= now;
      regularFor = now.difference(_regularSince!);
    } else {
      _regularSince = null;
      regularFor = Duration.zero;
      if (alarmFiring) alarmFiring = false;
    }

    if (!alarmFiring && regularFor >= alarmThreshold) {
      alarmFiring = true;
    }
    notifyListeners();
  }

  List<DateTime> _findPeaks() {
    final peaks = <DateTime>[];
    for (var i = 1; i < _samples.length - 1; i++) {
      final prev = _samples[i - 1].db;
      final cur = _samples[i].db;
      final next = _samples[i + 1].db;
      if (cur >= prev + _minPeakProminenceDb && cur >= next) {
        peaks.add(_samples[i].time);
      }
    }
    return peaks;
  }

  bool _isRegular(List<DateTime> peaks) {
    if (peaks.length < _requiredRegularCycles) return false;
    final intervals = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i].difference(peaks[i - 1]).inMilliseconds / 1000);
    }
    if (intervals.any((s) => s < _minCycleSeconds || s > _maxCycleSeconds)) {
      return false;
    }
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    if (mean == 0) return false;
    final variance =
        intervals.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) /
        intervals.length;
    // Coefficient of variation gate: breathing is metronomic, random noise isn't.
    final coeffOfVariation = sqrt(variance) / mean;
    return coeffOfVariation < 0.25;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _Sample {
  final DateTime time;
  final double db;
  _Sample(this.time, this.db);
}
