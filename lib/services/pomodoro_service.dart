import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_scheduler.dart';
import 'screen_wake.dart';

enum PomoPhase { idle, work, workDone, breakTime, breakDone }

/// ポモドーロ。作業と休憩を区切って、区間の終わりに合図する。
///
/// ## 壁時計で数える
/// [NapTimerService] は1秒ごとに int を減らしているが、背面に回ると Dart の
/// タイマーは止まったり間引かれたりする。ここは終了時刻 [endsAt] を持ち、
/// 毎秒「今から何秒残っているか」を**計算し直す**。復帰したときに正しい
/// 残り時間が出るし、[syncFromClock] で「もう終わっていた」も拾える。
///
/// ## 背面でも合図が届くように
/// 区間を始めるたびに終了時刻の通知を OS に予約する（[NotificationScheduler]）。
/// プロセスが死んでも通知は出る。前面で終わりを迎えたら予約は取り消して、
/// 画面側の合図に切り替える（二重に鳴らない）。inexact なので数分遅れうる。
///
/// ## 次の区間は自動で始めない
/// 作業→休憩→作業と勝手に進めると、背面で「何区間たったか」が曖昧になる。
/// 区間が終わったら本人が「開始」を押す。Web 版と同じ挙動。
class PomodoroService extends ChangeNotifier {
  PomodoroService(this._scheduler);

  final NotificationScheduler _scheduler;

  static const _kPhase = 'pomo_phase';
  static const _kEndsAt = 'pomo_ends_at';
  static const _kPausedLeft = 'pomo_paused_left';
  static const _kRound = 'pomo_round';
  static const _kWorkMin = 'pomo_work_min';
  static const _kBreakMin = 'pomo_break_min';
  static const _wakeKey = 'pomodoro';

  static const minWork = 15, maxWork = 60;
  static const minBreak = 3, maxBreak = 15;

  int workMinutes = 25;
  int breakMinutes = 5;
  int round = 0;
  PomoPhase phase = PomoPhase.idle;

  /// 走っている区間の終了時刻。一時停止中は null。
  DateTime? endsAt;

  /// 一時停止したときの残り。走っている間は null。
  Duration? pausedLeft;

  Timer? _ticker;

  /// 区間が終わったときに画面側へ知らせる口（音・振動・スナックバー）。
  void Function(PomoPhase finished)? onPhaseEnd;

  /// アプリが前面にいるか。HomeShell のライフサイクルから入る。
  ///
  /// ⚠️ プロセスが生きたまま背面にいると Dart のタイマーも動き続ける。
  /// そこで区間を終えて OS の予約を取り消してしまうと、**通知が一度も出ない**
  /// （実機で 19:55 の予約が消え、何も鳴らなかった）。背面では予約を残して
  /// OS に鳴らせる。前面なら画面側の合図に切り替えて予約を取り消す。
  bool inForeground = true;

  /// テストで時間を進めるための差し替え口。本番は [DateTime.now]。
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  bool get isRunning =>
      (phase == PomoPhase.work || phase == PomoPhase.breakTime) &&
      endsAt != null;

  bool get isPaused =>
      (phase == PomoPhase.work || phase == PomoPhase.breakTime) &&
      endsAt == null;

  bool get isWorkPhase => phase == PomoPhase.work;

  Duration get remaining {
    if (endsAt != null) {
      final d = endsAt!.difference(clock());
      return d.isNegative ? Duration.zero : d;
    }
    if (pausedLeft != null) return pausedLeft!;
    if (phase == PomoPhase.idle) return Duration(minutes: workMinutes);
    return Duration.zero;
  }

  Duration get phaseLength => Duration(
    minutes: phase == PomoPhase.breakTime ? breakMinutes : workMinutes,
  );

  double get fraction {
    final total = phaseLength.inSeconds;
    if (total == 0) return 0;
    return (remaining.inSeconds / total).clamp(0.0, 1.0);
  }

  String get formatted {
    final s = remaining.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    workMinutes = prefs.getInt(_kWorkMin) ?? 25;
    breakMinutes = prefs.getInt(_kBreakMin) ?? 5;
    round = prefs.getInt(_kRound) ?? 0;
    phase = PomoPhase.values.firstWhere(
      (p) => p.name == prefs.getString(_kPhase),
      orElse: () => PomoPhase.idle,
    );
    final ends = prefs.getInt(_kEndsAt);
    endsAt = ends == null ? null : DateTime.fromMillisecondsSinceEpoch(ends);
    final paused = prefs.getInt(_kPausedLeft);
    pausedLeft = paused == null ? null : Duration(seconds: paused);
    // 起動し直したら、走っていた区間はもう終わっているかもしれない。
    syncFromClock();
    if (isRunning) {
      _startTicker();
      // 強制終了やメーカーの省電力でプロセスが殺されると、OS の予約も
      // 一緒に消えることがある（am force-stop で実機確認）。走っている
      // なら張り直す。同じ id なので二重にはならない。
      await _scheduleEnd();
    }
    notifyListeners();
  }

  Future<void> _scheduleEnd() => _scheduler.scheduleAt(
    id: NotificationIds.pomodoro,
    channel: NotificationChannels.pomodoro,
    title: phase == PomoPhase.work ? '作業時間が終わりました' : '休憩が終わりました',
    body: phase == PomoPhase.work ? '休憩に入りましょう。' : '次の作業へ。',
    at: endsAt!,
  );

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWorkMin, workMinutes);
    await prefs.setInt(_kBreakMin, breakMinutes);
    await prefs.setInt(_kRound, round);
    await prefs.setString(_kPhase, phase.name);
    if (endsAt == null) {
      await prefs.remove(_kEndsAt);
    } else {
      await prefs.setInt(_kEndsAt, endsAt!.millisecondsSinceEpoch);
    }
    if (pausedLeft == null) {
      await prefs.remove(_kPausedLeft);
    } else {
      await prefs.setInt(_kPausedLeft, pausedLeft!.inSeconds);
    }
  }

  Future<void> setWorkMinutes(int m) async {
    workMinutes = m.clamp(minWork, maxWork);
    await _persist();
    notifyListeners();
  }

  Future<void> setBreakMinutes(int m) async {
    breakMinutes = m.clamp(minBreak, maxBreak);
    await _persist();
    notifyListeners();
  }

  /// 「開始」。idle と breakDone からは作業、workDone からは休憩へ。
  Future<void> start() async {
    if (isRunning || isPaused) return;
    final next = phase == PomoPhase.workDone
        ? PomoPhase.breakTime
        : PomoPhase.work;
    await _begin(next);
  }

  Future<void> _begin(PomoPhase next) async {
    phase = next;
    pausedLeft = null;
    endsAt = clock().add(phaseLength);
    await ScreenWake.acquire(_wakeKey);
    await _scheduleEnd();
    _startTicker();
    await _persist();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isRunning) return;
    pausedLeft = remaining;
    endsAt = null;
    _stopTicker();
    await _scheduler.cancel(NotificationIds.pomodoro);
    await ScreenWake.release(_wakeKey);
    await _persist();
    notifyListeners();
  }

  Future<void> resume() async {
    if (!isPaused) return;
    endsAt = clock().add(pausedLeft!);
    pausedLeft = null;
    await ScreenWake.acquire(_wakeKey);
    await _scheduleEnd();
    _startTicker();
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    _stopTicker();
    phase = PomoPhase.idle;
    endsAt = null;
    pausedLeft = null;
    round = 0;
    await _scheduler.cancel(NotificationIds.pomodoro);
    await ScreenWake.release(_wakeKey);
    await _persist();
    notifyListeners();
  }

  /// 時計に合わせて状態を進める。復帰時と毎秒呼ぶ。
  /// 「もう終わっていた」なら区間を終える。
  void syncFromClock() {
    if (!isRunning) return;
    if (!clock().isBefore(endsAt!)) _finishPhase();
  }

  void _finishPhase() {
    final finished = phase;
    _stopTicker();
    endsAt = null;
    pausedLeft = null;
    if (finished == PomoPhase.work) {
      round++;
      phase = PomoPhase.workDone;
    } else {
      phase = PomoPhase.breakDone;
    }
    unawaited(ScreenWake.release(_wakeKey));
    unawaited(_persist());
    if (inForeground) {
      // 前面で終わりを迎えた。画面側で合図するので予約した通知は要らない。
      unawaited(_scheduler.cancel(NotificationIds.pomodoro));
      onPhaseEnd?.call(finished);
    }
    // 背面なら何もしない。予約した通知が OS から出るのが合図。
    // ここで preview 音を鳴らすと通知の音と二重になる。
    notifyListeners();
  }

  /// 前面に戻った。背面で終わっていた区間を拾い、出ていた通知は片づける。
  void onForeground() {
    inForeground = true;
    syncFromClock();
    if (!isRunning) {
      // 終わった区間の通知がまだ通知欄に残っていれば、画面を見た時点で用済み。
      unawaited(_scheduler.cancel(NotificationIds.pomodoro));
    }
  }

  void onBackground() {
    inForeground = false;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      syncFromClock();
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
