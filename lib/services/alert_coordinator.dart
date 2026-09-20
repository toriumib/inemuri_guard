import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drowsiness_detector.dart';
import 'breathing_detector.dart';
import 'nap_timer_service.dart';

enum AlertSource { eyes, posture, breathing, nap, nudge }

/// One arbiter owns alarm output, independently of mounted screens.
/// Each source is withdrawn independently; a lower priority source cannot
/// silence a still-active higher priority source.
class AlertCoordinator extends ChangeNotifier {
  AlertCoordinator({
    required this.detector,
    required this.breathing,
    required this.nap,
    required this.applyAlarm,
    this.onEpisode,
    this.onLookAway,
    this.onRestAdvice,
  }) {
    detector.addListener(_schedule);
    breathing.addListener(_schedule);
    nap.addListener(_schedule);
    _schedule();
  }
  final DrowsinessDetector detector;
  final BreathingDetector breathing;
  final NapTimerService nap;
  final Future<void> Function(String? reason) applyAlarm;
  final void Function(AlertSource source)? onEpisode;
  final void Function()? onLookAway;
  final void Function()? onRestAdvice;
  Set<AlertSource> _active = {};
  Set<AlertSource> get active => Set.unmodifiable(_active);
  bool get isAlarming => _active.isNotEmpty;
  bool restAdvice = false;
  String? _nudge;
  String? get reason => _reason;
  String? _reason;
  String? outputFailure;
  bool _scheduled = false, _disposed = false, _applying = false;
  bool _lookAway = false;
  String? _applied;

  void requestNudge(String app) {
    _nudge = '$app の通知が届きました';
    _schedule();
  }

  void dismissRestAdvice() {
    restAdvice = false;
    notifyListeners();
  }

  void dismiss({bool snoozeNap = false}) {
    if (detector.alarmFiring) detector.snooze();
    if (breathing.alarmFiring) breathing.snooze();
    if (nap.phase == NapPhase.done) {
      if (snoozeNap) {
        nap.snooze();
      } else {
        nap.cancel();
      }
    }
    _nudge = null;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _sync();
    });
  }

  void _sync() {
    final next = <AlertSource>{
      if (detector.eyeAlarm) AlertSource.eyes,
      if (detector.postureAlarm) AlertSource.posture,
      if (breathing.alarmFiring) AlertSource.breathing,
      if (nap.phase == NapPhase.done) AlertSource.nap,
      if (_nudge != null) AlertSource.nudge,
    };
    final added = next.difference(_active);
    final changed = !setEquals(next, _active);
    _active = next;
    for (final source in added) {
      onEpisode?.call(source);
    }
    if (detector.carMode &&
        added.any(
          (s) =>
              s == AlertSource.eyes ||
              s == AlertSource.posture ||
              s == AlertSource.breathing,
        )) {
      restAdvice = true;
      onRestAdvice?.call();
    }
    if (detector.lookAwayAlert && !_lookAway && next.isEmpty) {
      onLookAway?.call();
    }
    _lookAway = detector.lookAwayAlert;
    final source = next.isEmpty ? null : next.first;
    final reason = switch (source) {
      AlertSource.eyes => '目を閉じたままの状態を検知しました',
      AlertSource.posture => '頭の傾きが続いています。姿勢を戻してください',
      AlertSource.breathing => '規則的な寝息のような音を検知しました',
      AlertSource.nap => '仮眠の終了時刻です',
      AlertSource.nudge => _nudge,
      null => null,
    };
    final reasonChanged = reason != _reason;
    _reason = reason;
    if (changed || reasonChanged) notifyListeners();
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_applying || _disposed) return;
    _applying = true;
    try {
      while (!_disposed && _applied != _reason) {
        final desired = _reason;
        try {
          await applyAlarm(desired);
          _applied = desired;
          if (outputFailure != null) {
            outputFailure = null;
            notifyListeners();
          }
        } catch (_) {
          outputFailure = 'アラーム出力に失敗しました。音の設定を確認してください。';
          notifyListeners();
          break;
        }
      }
    } finally {
      _applying = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    detector.removeListener(_schedule);
    breathing.removeListener(_schedule);
    nap.removeListener(_schedule);
    super.dispose();
  }
}
