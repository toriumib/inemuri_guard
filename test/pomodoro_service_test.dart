import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/notification_scheduler.dart';
import 'package:inemuri_guard/services/pomodoro_service.dart';
import 'package:inemuri_guard/services/screen_wake.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

class _Clock {
  DateTime now = DateTime(2026, 9, 11, 10);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeScheduler sched;
  late _Clock clock;
  late PomodoroService p;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ScreenWake.resetForTest();
    sched = FakeScheduler();
    clock = _Clock();
    p = PomodoroService(sched)..clock = clock.call;
    await p.load();
  });

  test('開始で終了時刻が置かれ、通知が予約される', () async {
    await p.start();
    expect(p.phase, PomoPhase.work);
    expect(p.endsAt, clock.now.add(const Duration(minutes: 25)));
    expect(sched.scheduled[NotificationIds.pomodoro], p.endsAt);
    expect(p.formatted, '25:00');
  });

  test('残り時間は壁時計から計算し直す', () async {
    await p.start();
    clock.advance(const Duration(minutes: 10));
    expect(p.formatted, '15:00');
  });

  test('時間が来たら作業終了になり、ラウンドが増え、予約は取り消される', () async {
    final ended = <PomoPhase>[];
    p.onPhaseEnd = ended.add;
    await p.start();
    clock.advance(const Duration(minutes: 25));
    p.syncFromClock();
    expect(p.phase, PomoPhase.workDone);
    expect(p.round, 1);
    expect(ended, [PomoPhase.work]);
    await Future<void>.delayed(Duration.zero); // unawaited の取り消しを流す
    expect(sched.cancelled, contains(NotificationIds.pomodoro));
  });

  test('作業終了のあとの開始は休憩、休憩終了のあとの開始は作業', () async {
    await p.start();
    clock.advance(const Duration(minutes: 25));
    p.syncFromClock();
    await p.start();
    expect(p.phase, PomoPhase.breakTime);
    expect(p.formatted, '05:00');
    clock.advance(const Duration(minutes: 5));
    p.syncFromClock();
    expect(p.phase, PomoPhase.breakDone);
    await p.start();
    expect(p.phase, PomoPhase.work);
    expect(p.round, 1, reason: '休憩ではラウンドは増えない');
  });

  test('一時停止で残りが保たれ、再開で続きから', () async {
    await p.start();
    clock.advance(const Duration(minutes: 10));
    await p.pause();
    expect(p.isPaused, isTrue);
    expect(p.formatted, '15:00');
    expect(sched.scheduled.containsKey(NotificationIds.pomodoro), isFalse,
        reason: '止めている間に通知が鳴ってはいけない');
    clock.advance(const Duration(hours: 1));
    expect(p.formatted, '15:00', reason: '止めている間は減らない');
    await p.resume();
    expect(p.isRunning, isTrue);
    expect(p.endsAt, clock.now.add(const Duration(minutes: 15)));
    expect(sched.scheduled[NotificationIds.pomodoro], p.endsAt);
  });

  test('起動し直したとき、終了時刻を過ぎていれば作業終了として復元する', () async {
    await p.start();
    // 別インスタンスで読み直す（プロセスが死んで戻ってきた想定）。
    final later = _Clock()..now = clock.now.add(const Duration(minutes: 40));
    final q = PomodoroService(sched)..clock = later.call;
    await q.load();
    expect(q.phase, PomoPhase.workDone);
    expect(q.round, 1);
    expect(q.formatted, '00:00', reason: 'マイナス表示にしない');
  });

  test('起動し直したとき、まだ走っていれば予約を張り直す', () async {
    await p.start();
    // プロセスが殺されて OS の予約も消えた想定。
    sched.scheduled.clear();
    final later = _Clock()..now = clock.now.add(const Duration(minutes: 5));
    final q = PomodoroService(sched)..clock = later.call;
    await q.load();
    expect(q.isRunning, isTrue);
    expect(sched.scheduled[NotificationIds.pomodoro], q.endsAt,
        reason: 'force-stop で予約が消えても、起動時に張り直す');
  });

  test('背面で時間が来ても予約は消さず、画面の合図も出さない', () async {
    // プロセスが生きたまま背面にいると Dart のタイマーも動く。そこで予約を
    // 消すと通知が一度も出ない（実機で 19:55 の予約が消えて何も鳴らなかった）。
    final ended = <PomoPhase>[];
    p.onPhaseEnd = ended.add;
    await p.start();
    p.onBackground();
    clock.advance(const Duration(minutes: 25));
    p.syncFromClock();
    await Future<void>.delayed(Duration.zero);
    expect(p.phase, PomoPhase.workDone);
    expect(sched.scheduled.containsKey(NotificationIds.pomodoro), isTrue,
        reason: '背面では OS の通知が合図。予約を残す');
    expect(ended, isEmpty, reason: '通知の音と二重にしない');
    // 前面に戻ったら、出ていた通知は片づける。
    p.onForeground();
    await Future<void>.delayed(Duration.zero);
    expect(sched.scheduled.containsKey(NotificationIds.pomodoro), isFalse);
  });

  test('リセットで最初に戻る', () async {
    await p.start();
    clock.advance(const Duration(minutes: 25));
    p.syncFromClock();
    await p.reset();
    expect(p.phase, PomoPhase.idle);
    expect(p.round, 0);
    expect(p.formatted, '25:00');
  });

  test('作業・休憩の長さは範囲に収める', () async {
    await p.setWorkMinutes(5);
    expect(p.workMinutes, PomodoroService.minWork);
    await p.setBreakMinutes(99);
    expect(p.breakMinutes, PomodoroService.maxBreak);
  });
}
