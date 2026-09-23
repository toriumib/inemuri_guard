import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inemuri_guard/l10n/app_language.dart';
import 'package:inemuri_guard/screens/detect_screen.dart';
import 'package:inemuri_guard/screens/terms_gate.dart';
import 'package:inemuri_guard/services/alarm_service.dart';
import 'package:inemuri_guard/services/alert_coordinator.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/device_readiness.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/nap_timer_service.dart';
import 'package:inemuri_guard/services/notification_service.dart';
import 'package:inemuri_guard/services/stats_service.dart';
import 'package:inemuri_guard/widgets/first_use_card.dart';
import 'package:inemuri_guard/widgets/sensitivity_control.dart';
import 'package:inemuri_guard/widgets/wake_up_overlay.dart';

class _Detector extends DrowsinessDetector {
  @override
  Future<void> start() async {
    state = DetectorState.watching;
    inputStalled = false;
    noteFaceSeen();
    ingestEyes(1, 1);
    ingestPose(0, 0, 0);
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    state = DetectorState.idle;
    notifyListeners();
  }
}

class _Alarm extends ChangeNotifier implements AlarmService {
  int previews = 0;
  @override
  bool useTorch = false;
  @override
  Future<void> preview() async => previews++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget localized(Widget home, {double textScale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: (locales, _) =>
      AppLanguage.resolve(locales ?? []),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'locale resolution honors supported device preferences and fallback',
    () {
      expect(
        AppLanguage.resolve([const Locale('ja', 'JP')]),
        const Locale('ja'),
      );
      expect(
        AppLanguage.resolve([const Locale('en', 'GB'), const Locale('ja')]),
        const Locale('en'),
      );
      expect(
        AppLanguage.resolve([const Locale('fr'), const Locale('ja')]),
        const Locale('ja'),
      );
      expect(AppLanguage.resolve([const Locale('fr')]), const Locale('en'));
      expect(AppLanguage.resolve([]), const Locale('en'));
    },
  );

  for (final code in ['ja', 'en']) {
    testWidgets('$code terms are readable and agreement remains explicit', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [Locale(code)];
      var accepted = false;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localized(TermsGate(onAccept: () => accepted = true), textScale: 1.5),
      );
      await tester.pumpAndSettle();
      expect(accepted, false);
      await tester.tap(find.text(AppLanguage.current.agreeStart));
      expect(accepted, true);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('English first use, sound check, input recovery and stop', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('en', 'GB'),
    ];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceReadiness.channel,
          (_) async => {'alarmVolume': 4, 'notifications': true},
        );
    final stats = StatsService();
    await stats.load();
    final detector = _Detector();
    final alarm = _Alarm();
    final breathing = BreathingDetector();
    final nap = NapTimerService();
    final device = DeviceReadiness();
    final alerts = AlertCoordinator(
      detector: detector,
      breathing: breathing,
      nap: nap,
      applyAlarm: (_) async {},
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider<DrowsinessDetector>.value(value: detector),
          ChangeNotifierProvider<AlarmService>.value(value: alarm),
          ChangeNotifierProvider.value(value: breathing),
          ChangeNotifierProvider.value(value: alerts),
          ChangeNotifierProvider.value(value: device),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: localized(
            const Scaffold(body: SafeArea(child: DetectScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(detector.state, DetectorState.idle);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Check the sound'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('watch-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start monitoring'));
    await tester.pumpAndSettle();
    expect(find.text('Stop monitoring'), findsOneWidget);
    // 一覧が長いと先頭のカードは描画範囲の外に出るので、先頭へ戻す。
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check the sound'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check the sound'));
    await tester.pumpAndSettle();
    expect(alarm.previews, 1);
    expect(stats.setupCompleted, false);
    await tester.tap(find.text('I heard it — finish setup'));
    await tester.pumpAndSettle();
    expect(stats.setupCompleted, true);
    expect(find.text('Quick setup'), findsNothing);
    detector.inputStalled = true;
    detector.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Camera input stopped'), findsOneWidget);
    await tester.ensureVisible(find.text('Reconnect camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconnect camera'));
    await tester.pumpAndSettle();
    expect(detector.inputStalled, false);
    await tester.ensureVisible(find.byKey(const Key('watch-toggle')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/english-monitor-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Stop monitoring'));
    await tester.pumpAndSettle();
    expect(detector.state, DetectorState.idle);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    alerts.dispose();
    breathing.dispose();
    nap.dispose();
    device.dispose();
  });

  testWidgets('system language change retains first-use progress', (
    tester,
  ) async {
    final detector = _Detector();
    final stats = StatsService();
    final alarm = _Alarm();
    await stats.load();
    await detector.start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider<DrowsinessDetector>.value(value: detector),
          ChangeNotifierProvider<AlarmService>.value(value: alarm),
        ],
        child: localized(
          const Scaffold(body: SingleChildScrollView(child: FirstUseCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('音を確認する'));
    await tester.pumpAndSettle();
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpAndSettle();
    expect(find.text('I heard it — finish setup'), findsOneWidget);
    expect(detector.state, DetectorState.watching);
    await tester.tap(find.text('I heard it — finish setup'));
    await tester.pumpAndSettle();
    expect(stats.setupCompleted, true);
    expect(alarm.previews, 1);
  });

  testWidgets(
    'English alert and custom sensitivity fit narrow large-text screens',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var stopped = false;
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: WakeUpOverlay(
              active: true,
              message: 'Wake up! Open your eyes',
              onWake: () => stopped = true,
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I’m awake — stop'));
      expect(stopped, true);
      expect(tester.takeException(), isNull);
      final stats = StatsService();
      await stats.load();
      await stats.setSensitivity(DetectionSensitivity.custom);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: stats),
            ChangeNotifierProvider<DrowsinessDetector>(
              create: (_) => _Detector(),
            ),
          ],
          child: localized(
            const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SensitivityControl(),
                ),
              ),
            ),
            textScale: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('seconds of closed eyes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('alarm action follows the language without changing its identifier', () {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final notifications = NotificationService();
    expect(
      notifications.alarmNotificationDetails().actions!.single.title,
      '止める',
    );
    binding.platformDispatcher.localesTestValue = const [Locale('en')];
    final action = notifications.alarmNotificationDetails().actions!.single;
    expect(action.title, 'Stop');
    expect(action.id, NotificationService.stopActionId);
  });
}
