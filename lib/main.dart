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
  await adService.init();

  final notifications = NotificationService();
  await notifications.init();
  // 時計への通知転送は設定で切れる。起動時に保存値を反映する。
  notifications.bridgeToWatch = stats.watchBridge;

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
