import 'dart:io';
import 'package:inemuri_guard/widgets/first_use_card.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inemuri_guard/screens/detect_screen.dart';
import 'package:inemuri_guard/services/alarm_service.dart';
import 'package:inemuri_guard/services/alert_coordinator.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/device_readiness.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/nap_timer_service.dart';
import 'package:inemuri_guard/services/stats_service.dart';
import 'package:inemuri_guard/widgets/status_hero.dart';
import 'package:inemuri_guard/widgets/wake_up_overlay.dart';

class _Detector extends DrowsinessDetector {
  int starts = 0;
  @override
  Future<void> start() async {
    starts++;
    state = DetectorState.watching;
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
  Future<void> preview() async {
    previews++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceReadiness.channel,
          (call) async => switch (call.method) {
            'status' => {
              'alarmVolume': 4,
              'alarmMax': 7,
              'notifications': true,
              'canAddTile': true,
            },
            'consumeStartRequest' => false,
            _ => true,
          },
        );
  });
  test(
    'native setup reflects silence and handles missing settings safely',
    () async {
      final device = DeviceReadiness();
      await device.refresh();
      expect(device.silent, false);
      expect(device.canAddTile, true);
      expect(await device.open('addTile'), true);
      expect(device.tileAdded, true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceReadiness.channel, (call) async {
            if (call.method == 'status') {
              return {'alarmVolume': 0, 'notifications': false};
            }
            throw PlatformException(code: 'unavailable');
          });
      await device.refresh();
      expect(device.silent, true);
      expect(device.notifications, false);
      expect(await device.open('soundSettings'), false);
      expect(device.busy, false);
      device.dispose();
    },
  );
  test('flashing is opt-in and persists', () async {
    final stats = StatsService();
    await stats.load();
    expect(stats.flashAlarm, false);
    await stats.setFlashAlarm(true);
    final restored = StatsService();
    await restored.load();
    expect(restored.flashAlarm, true);
  });
  testWidgets(
    'first-use setup requires visible eyes and explicit sound confirmation',
    (tester) async {
      final stats = StatsService();
      await stats.load();
      final detector = _Detector();
      final alarm = _Alarm();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: stats),
            ChangeNotifierProvider<DrowsinessDetector>.value(value: detector),
            ChangeNotifierProvider<AlarmService>.value(value: alarm),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: FirstUseCard())),
          ),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '音を確認する'),
            )
            .onPressed,
        isNull,
      );
      await detector.start();
      await tester.pump();
      await tester.tap(find.text('音を確認する'));
      await tester.pump();
      expect(alarm.previews, 1);
      expect(stats.setupCompleted, false);
      detector.inputStalled = true;
      detector.notifyListeners();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '聞こえた・準備完了'),
            )
            .onPressed,
        isNull,
      );
      detector.inputStalled = false;
      detector.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('聞こえた・準備完了'));
      await tester.pumpAndSettle();
      expect(find.text('はじめの準備'), findsNothing);
      final restored = StatsService();
      await restored.load();
      expect(restored.setupCompleted, true);
    },
  );
  testWidgets('start, sound check and stop need no advanced settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final d = _Detector();
    final b = BreathingDetector();
    final n = NapTimerService();
    final stats = StatsService();
    final alarm = _Alarm();
    final device = DeviceReadiness();
    final alerts = AlertCoordinator(
      detector: d,
      breathing: b,
      nap: n,
      applyAlarm: (_) async {},
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DrowsinessDetector>.value(value: d),
          ChangeNotifierProvider.value(value: b),
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider.value(value: alerts),
          ChangeNotifierProvider.value(value: device),
          ChangeNotifierProvider<AlarmService>.value(value: alarm),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            home: const Scaffold(body: SafeArea(child: DetectScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('標準'), findsNothing);
    await tester.tap(find.byKey(const Key('watch-toggle')));
    await tester.pumpAndSettle();
    expect(d.starts, 1);
    expect(find.text('見張りを止める'), findsOneWidget);
    await tester.tap(find.text('音を試す'));
    await tester.pump();
    expect(alarm.previews, 1);
    // A reproducible preview of the actual widget layout, without camera hardware.
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/easy-start-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byKey(const Key('watch-toggle')));
    await tester.pumpAndSettle();
    expect(d.state, DetectorState.idle);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    alerts.dispose();
    device.dispose();
    b.dispose();
    n.dispose();
  });
  testWidgets('large text keeps status and alarm controls accessible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var stops = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              StatusHero(
                mode: StatusMode.warn,
                label: '監視状態',
                value: '姿勢のみ監視中（目を読めません）',
                primaryLabel: '見張りを止める',
                onPrimary: () => stops++,
              ),
              Expanded(
                child: WakeUpOverlay(
                  active: true,
                  message: '頭を起こしてください',
                  onWake: () => stops++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('起きた・止める'));
    await tester.pump();
    expect(stops, 1);
    expect(tester.takeException(), isNull);
  });
}
