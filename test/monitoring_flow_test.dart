import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/nap_timer_service.dart';
import 'package:inemuri_guard/services/alert_coordinator.dart';
import 'package:inemuri_guard/services/stats_service.dart';
import 'package:inemuri_guard/widgets/monitoring_status.dart';
import 'package:inemuri_guard/widgets/sensitivity_control.dart';
import 'package:inemuri_guard/theme/app_theme.dart';

void main() {
  testWidgets('monitoring → face lost → recovered → microphone failed', (
    tester,
  ) async {
    final d = DrowsinessDetector()..state = DetectorState.watching;
    final b = BreathingDetector();
    final n = NapTimerService();
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: n,
      applyAlarm: (_) async {},
    );
    Widget app() => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: d),
        ChangeNotifierProvider.value(value: b),
        ChangeNotifierProvider.value(value: alerts),
      ],
      child: const MaterialApp(home: Scaffold(body: MonitoringStatus())),
    );
    d.noteFaceSeen();
    d.ingestEyes(1, 1);
    d.ingestPose(0, 0, 0);
    await tester.pumpWidget(app());
    expect(find.text('目と姿勢を監視中'), findsOneWidget);
    d.noteFaceLost();
    await tester.pumpWidget(app());
    expect(find.text('対象の顔が見えません'), findsOneWidget);
    d.noteFaceSeen();
    d.ingestEyes(1, 1);
    d.ingestPose(0, 0, 0);
    await tester.pumpWidget(app());
    expect(find.text('目と姿勢を監視中'), findsOneWidget);
    b.state = MicState.listening;
    b.noteInputFailure();
    await tester.pump();
    expect(find.textContaining('マイク入力が停止'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    alerts.dispose();
    b.dispose();
    n.dispose();
  });
  testWidgets('sensitivity selections apply and persist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService();
    await stats.load();
    final d = DrowsinessDetector();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider.value(value: d),
        ],
        child: MaterialApp(
          theme: AppTheme.lightFor(stats.selectedSkin),
          home: const Scaffold(
            body: SingleChildScrollView(child: SensitivityControl()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('敏感'));
    await tester.pumpAndSettle();
    expect(d.closedThreshold.inSeconds, 3);
    final restored = StatsService();
    await restored.load();
    expect(restored.sensitivity, DetectionSensitivity.sensitive);
    expect(restored.eyeThresholdSeconds, 3);
    await tester.tap(find.text('詳細設定'));
    await tester.pumpAndSettle();
    expect(find.text('連続何秒で知らせる？'), findsOneWidget);
    await tester.tap(find.text('標準'));
    await tester.pumpAndSettle();
    expect(d.closedThreshold.inSeconds, 5);
    await tester.pumpWidget(const SizedBox());
  });
}
