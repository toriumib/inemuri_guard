import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/alert_coordinator.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/nap_timer_service.dart';

void main() {
  test('retains lower priority alert after higher priority clears', () async {
    final d = DrowsinessDetector();
    final b = BreathingDetector();
    final nap = NapTimerService();
    final outputs = <String?>[];
    final episodes = <AlertSource>[];
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: nap,
      applyAlarm: (reason) async {
        outputs.add(reason);
      },
      onEpisode: episodes.add,
    );
    b.alarmFiring = true;
    alerts.requestNudge('テスト');
    await Future<void>.delayed(Duration.zero);
    expect(
      alerts.active,
      containsAll([AlertSource.breathing, AlertSource.nudge]),
    );
    expect(outputs.last, contains('寝息'));
    b.snooze();
    await Future<void>.delayed(Duration.zero);
    expect(outputs.last, contains('テスト'));
    expect(outputs, isNot(contains(null)));
    alerts.dismiss();
    await Future<void>.delayed(Duration.zero);
    expect(outputs.last, isNull);
    expect(episodes.where((s) => s == AlertSource.breathing).length, 1);
    alerts.dispose();
    b.dispose();
    nap.dispose();
  });
  test(
    'a delayed start is followed by stop when dismissed during await',
    () async {
      final d = DrowsinessDetector();
      final b = BreathingDetector();
      final n = NapTimerService();
      final started = Completer<void>();
      final outputs = <String?>[];
      final alerts = AlertCoordinator(
        detector: d,
        breathing: b,
        nap: n,
        applyAlarm: (reason) async {
          outputs.add(reason);
          if (reason != null) await started.future;
        },
      );
      alerts.requestNudge('テスト');
      await Future<void>.delayed(Duration.zero);
      alerts.dismiss();
      await Future<void>.delayed(Duration.zero);
      started.complete();
      await Future<void>.delayed(Duration.zero);
      expect(outputs.length, 2);
      expect(outputs.last, isNull);
      alerts.dispose();
      b.dispose();
      n.dispose();
    },
  );
  test('nap ending cannot silence a breathing alert', () async {
    final d = DrowsinessDetector();
    final b = BreathingDetector();
    final n = NapTimerService();
    final outputs = <String?>[];
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: n,
      applyAlarm: (reason) async {
        outputs.add(reason);
      },
    );
    b.alarmFiring = true;
    n.phase = NapPhase.done;
    n.selectPreset(10);
    await Future<void>.delayed(Duration.zero);
    expect(
      alerts.active,
      containsAll([AlertSource.breathing, AlertSource.nap]),
    );
    n.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(alerts.active, {AlertSource.breathing});
    expect(outputs, isNot(contains(null)));
    alerts.dispose();
    b.dispose();
    n.dispose();
  });

  test('車モードで居眠りのアラームが 20 秒止まらなければ一度だけ異常時対応へ', () async {
    final d = DrowsinessDetector()..carMode = true;
    final b = BreathingDetector();
    final nap = NapTimerService();
    var calls = 0;
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: nap,
      applyAlarm: (_) async {},
      onUnresponsive: () => calls++,
    );
    b.alarmFiring = true;
    alerts.requestNudge('x'); // 同期させる（寝息のアラームを拾わせる）
    await Future<void>.delayed(Duration.zero);
    final now = DateTime.now();
    alerts.checkUnresponsive(now.add(const Duration(seconds: 10)));
    expect(calls, 0, reason: '20 秒たっていない');
    alerts.checkUnresponsive(now.add(const Duration(seconds: 21)));
    alerts.checkUnresponsive(now.add(const Duration(seconds: 40)));
    expect(calls, 1, reason: '1 回の鳴動につき一度');
    d.carMode = false;
    alerts.dispose();
    b.dispose();
    nap.dispose();
  });

  test('机では異常時対応に進まない', () async {
    final d = DrowsinessDetector();
    final b = BreathingDetector();
    final nap = NapTimerService();
    var calls = 0;
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: nap,
      applyAlarm: (_) async {},
      onUnresponsive: () => calls++,
    );
    b.alarmFiring = true;
    alerts.requestNudge('x');
    await Future<void>.delayed(Duration.zero);
    alerts.checkUnresponsive(DateTime.now().add(const Duration(minutes: 5)));
    expect(calls, 0);
    alerts.dispose();
    b.dispose();
    nap.dispose();
  });
}
