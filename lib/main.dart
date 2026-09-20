import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/terms_gate.dart';
import 'services/ad_service.dart';
import 'services/alarm_service.dart';
import 'services/alert_coordinator.dart';
import 'services/breathing_detector.dart';
import 'services/car_trigger.dart';
import 'services/device_readiness.dart';
import 'services/drowsiness_detector.dart';
import 'services/hydration_service.dart';
import 'services/nap_timer_service.dart';
import 'services/notification_service.dart';
import 'services/nudge_service.dart';
import 'services/pomodoro_service.dart';
import 'services/purchase_service.dart';
import 'services/sleep_log_service.dart';
import 'services/sleep_time_log_service.dart';
import 'services/stats_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stats = StatsService();
  await stats.load();

  final sleepLog = SleepLogService();
  await sleepLog.load();

  final adService = AdService();
  // 広告SDKの初期化は待たない。Play servicesが不調な環境で
  // MobileAds.initialize() が戻らなくなり、通知もUIも始動しないのを
  // エミュレータで確認した。広告は準備できたものから載る。
  unawaited(adService.init().catchError((_) {}));

  final notifications = NotificationService();
  await notifications.init();
  // 時計への通知転送は設定で切れる。起動時に保存値を反映する。
  notifications.bridgeToWatch = stats.watchBridge;

  // 通知経路の検証用（--dart-define=FIRE_NOTIFICATION_TEST=true のdebugビルド限定）。
  // 起動3秒後にアラーム通知を1回だけ出す。リリースビルドには入らない。
  if (kDebugMode && const bool.fromEnvironment('FIRE_NOTIFICATION_TEST')) {
    Future.delayed(const Duration(seconds: 3), () {
      notifications.fireAlarm('起きてください', '通知経路の確認（dart-define）');
    });
  }

  final nudge = NudgeService();
  // 車に乗ったら始める（Bluetooth／運転検知）。保存値を読んで購読を張る。
  final car = CarTrigger();
  await car.load();

  // 予約通知に頼る2つは、通知の初期化が終わってから。
  final pomodoro = PomodoroService(notifications);
  await pomodoro.load();
  final hydration = HydrationService(notifications);
  await hydration.load();
  final sleepTime = SleepTimeLogService();
  await sleepTime.load();

  runApp(
    InemuriGuardApp(
      stats: stats,
      sleepLog: sleepLog,
      sleepTime: sleepTime,
      pomodoro: pomodoro,
      hydration: hydration,
      nudge: nudge,
      car: car,
      adService: adService,
      notifications: notifications,
    ),
  );
}

class InemuriGuardApp extends StatelessWidget {
  final StatsService stats;
  final SleepLogService sleepLog;
  final SleepTimeLogService sleepTime;
  final PomodoroService pomodoro;
  final HydrationService hydration;
  final NudgeService nudge;
  final CarTrigger car;
  final AdService adService;
  final NotificationService notifications;
  const InemuriGuardApp({
    super.key,
    required this.stats,
    required this.sleepLog,
    required this.sleepTime,
    required this.pomodoro,
    required this.hydration,
    required this.nudge,
    required this.car,
    required this.adService,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: stats),
        ChangeNotifierProvider(create: (_) => DeviceReadiness()),
        ChangeNotifierProvider.value(value: sleepLog),
        ChangeNotifierProvider.value(value: sleepTime),
        ChangeNotifierProvider.value(value: pomodoro),
        ChangeNotifierProvider.value(value: hydration),
        ChangeNotifierProvider.value(value: nudge),
        ChangeNotifierProvider.value(value: car),
        Provider.value(value: adService),
        Provider.value(value: notifications),
        ChangeNotifierProvider(create: (_) => AlarmService(notifications)),
        ChangeNotifierProvider(create: (_) => DrowsinessDetector()),
        ChangeNotifierProvider(create: (_) => BreathingDetector()),
        ChangeNotifierProvider(create: (_) => NapTimerService()),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => AlertCoordinator(
            detector: context.read<DrowsinessDetector>(),
            breathing: context.read<BreathingDetector>(),
            nap: context.read<NapTimerService>(),
            applyAlarm: (reason) => reason == null
                ? context.read<AlarmService>().stop()
                : context.read<AlarmService>().start(reason: reason),
            onEpisode: (source) {
              if (source == AlertSource.nap || source == AlertSource.nudge) {
                return;
              }
              final text = switch (source) {
                AlertSource.eyes => '目の開閉',
                AlertSource.posture => '姿勢の傾き',
                _ => '寝息のような音',
              };
              unawaited(stats.bumpAlarm(text));
              unawaited(sleepLog.add(SleepEventType.detected, note: text));
            },
            onLookAway: () => unawaited(
              context.read<AlarmService>().warn().catchError((_) {}),
            ),
            onRestAdvice: () {
              if (WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed) {
                unawaited(notifications.fireRestAdvice());
              }
            },
          ),
        ),
        ChangeNotifierProxyProvider<StatsService, PurchaseService>(
          create: (_) => PurchaseService(stats)..init(),
          update: (_, stats, previous) =>
              previous ?? (PurchaseService(stats)..init()),
        ),
      ],
      // Watches the selected skin so buying/switching a theme repaints the
      // whole app immediately, in both light and dark.
      child: Consumer<StatsService>(
        builder: (context, stats, _) => MaterialApp(
          title: '居眠りガード',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightFor(stats.selectedSkin),
          darkTheme: AppTheme.darkFor(stats.selectedSkin),
          themeMode: ThemeMode.system,
          // 同意するまで HomeShell を作らない。HomeShell の initState が
          // 自動開始を担うので、同意→初回のカメラ許可、の順になる。
          home: stats.termsAcceptedVersion >= TermsGate.version
              ? const HomeShell()
              : TermsGate(onAccept: () => stats.acceptTerms(TermsGate.version)),
        ),
      ),
    );
  }
}
