import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/ad_service.dart';
import 'services/alarm_service.dart';
import 'services/breathing_detector.dart';
import 'services/drowsiness_detector.dart';
import 'services/nap_timer_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/sleep_log_service.dart';
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

  runApp(
    InemuriGuardApp(
      stats: stats,
      sleepLog: sleepLog,
      adService: adService,
      notifications: notifications,
    ),
  );
}

class InemuriGuardApp extends StatelessWidget {
  final StatsService stats;
  final SleepLogService sleepLog;
  final AdService adService;
  final NotificationService notifications;
  const InemuriGuardApp({
    super.key,
    required this.stats,
    required this.sleepLog,
    required this.adService,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: stats),
        ChangeNotifierProvider.value(value: sleepLog),
        Provider.value(value: adService),
        Provider.value(value: notifications),
        ChangeNotifierProvider(create: (_) => AlarmService(notifications)),
        ChangeNotifierProvider(create: (_) => DrowsinessDetector()),
        ChangeNotifierProvider(create: (_) => BreathingDetector()),
        ChangeNotifierProvider(create: (_) => NapTimerService()),
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
          home: const HomeShell(),
        ),
      ),
    );
  }
}
