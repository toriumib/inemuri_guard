import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inemuri_guard/services/notification_service.dart';
import 'package:inemuri_guard/services/notification_scheduler.dart';
import 'package:inemuri_guard/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('watch alarm is clearable and never uses ongoing/local-only flags', () {
    final service = NotificationService();
    final details = service.alarmNotificationDetails();
    expect(details.ongoing, false);
    expect(details.additionalFlags, isNull);
    expect(details.enableVibration, true);
    expect(details.actions!.single.id, NotificationService.stopActionId);
    expect(details.fullScreenIntent, true);
  });
  test('disabling bridge preserves phone alert but marks it local only', () {
    final service = NotificationService()..bridgeToWatch = false;
    final details = service.alarmNotificationDetails();
    expect(details.additionalFlags, contains(0x100));
    expect(details.enableVibration, true);
    expect(details.actions!.single.id, NotificationService.stopActionId);
  });
  test(
    'watch test shares alarm channel without opening or stopping alarm',
    () async {
      final service = NotificationService();
      final alarm = service.alarmNotificationDetails();
      final preview = service.alarmNotificationDetails(test: true);
      expect(preview.channelId, alarm.channelId);
      expect(preview.ongoing, false);
      expect(preview.fullScreenIntent, false);
      expect(preview.actions, isEmpty);
      expect(preview.autoCancel, true);
      expect(NotificationIds.watchTest, isNot(NotificationIds.alarm));
      expect(await service.testWatchNotification(), false);
    },
  );
  test('watch forwarding is on by default and remembers opt out', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService();
    await stats.load();
    expect(stats.watchBridge, true);
    await stats.setWatchBridge(false);
    final reloaded = StatsService();
    await reloaded.load();
    expect(reloaded.watchBridge, false);
  });
}
