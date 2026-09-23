import '../l10n/app_language.dart';
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
    this.onUnresponsive,
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

  /// ドライバー異常時対応（EDSS の考え方）。車モードで、居眠りのアラーム
  /// （目・姿勢・寝息）が [unresponsiveAfter] 鳴り続けても止まらない＝反応が無い。
  /// 1 回の鳴動につき一度だけ呼ぶ。
  final void Function()? onUnresponsive;
  static const unresponsiveAfter = Duration(seconds: 20);
  DateTime? _drowsySince;
  bool _escalated = false;
  Timer? _watchdog;

  /// 鳴り続けている時間を見て、反応が無ければ [onUnresponsive] を呼ぶ。
  /// 1 秒ごとのタイマーから呼ぶ。テストでは時刻を渡して直接呼ぶ。
  void checkUnresponsive(DateTime now) {
    final since = _drowsySince;
    if (since == null || _escalated || !detector.carMode) return;
    if (now.difference(since) < unresponsiveAfter) return;
    _escalated = true;
    onUnresponsive?.call();
  }
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
    _nudge = AppLanguage.current.nudgeReason(app);
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
    final drowsy = next.any(
      (s) =>
          s == AlertSource.eyes ||
          s == AlertSource.posture ||
          s == AlertSource.breathing,
    );
    if (drowsy) {
      _drowsySince ??= DateTime.now();
      _watchdog ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => checkUnresponsive(DateTime.now()),
      );
    } else {
      _drowsySince = null;
      _escalated = false;
      _watchdog?.cancel();
      _watchdog = null;
    }
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
      AlertSource.eyes => AppLanguage.current.eyesClosedReason,
      AlertSource.posture => AppLanguage.current.headTiltReason,
      AlertSource.breathing => AppLanguage.current.breathingReason,
      AlertSource.nap => AppLanguage.current.napReason,
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
          outputFailure = AppLanguage.current.alarmOutputFailed;
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
    _watchdog?.cancel();
    detector.removeListener(_schedule);
    breathing.removeListener(_schedule);
    nap.removeListener(_schedule);
    super.dispose();
  }
}
