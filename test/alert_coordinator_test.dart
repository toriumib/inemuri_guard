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
}
