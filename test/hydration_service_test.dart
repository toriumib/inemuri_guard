import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/hydration_service.dart';
import 'package:inemuri_guard/services/notification_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 11, 10, 10);

  group('planSlots', () {
    test('今日の残りは次の刻みから、明日は 09:45 から', () {
      final slots = HydrationService.planSlots(
        now: now,
        intervalMinutes: 45,
        fromHour: 9,
        toHour: 18,
      );
      // 9:00 起点で 45 分刻み: 9:45, 10:30, 11:15 … 17:15。10:10 の次は 10:30。
      expect(slots.first, DateTime(2026, 9, 11, 10, 30));
      final todays = slots.where((t) => t.day == 11).toList();
      expect(todays.last, DateTime(2026, 9, 11, 17, 15));
      final tomorrows = slots.where((t) => t.day == 12).toList();
      expect(tomorrows.first, DateTime(2026, 9, 12, 9, 45));
      expect(tomorrows.last, DateTime(2026, 9, 12, 17, 15));
    });

    test('時間帯の外では鳴らない', () {
      final slots = HydrationService.planSlots(
        now: now,
        intervalMinutes: 60,
        fromHour: 9,
        toHour: 12,
      );
      expect(slots.every((t) => t.hour >= 10 && t.hour < 12), isTrue);
    });

    test('開始 ≥ 終了なら空', () {
      expect(
        HydrationService.planSlots(
          now: now,
          intervalMinutes: 30,
          fromHour: 18,
          toHour: 9,
        ),
        isEmpty,
      );
    });

    test('通知 id の幅を超えない', () {
      final slots = HydrationService.planSlots(
        now: DateTime(2026, 9, 11, 0, 0),
        intervalMinutes: 1, // わざと細かく
        fromHour: 0,
        toHour: 23,
      );
      expect(
        slots.length,
        NotificationIds.hydrationToExclusive - NotificationIds.hydrationFrom,
      );
    });
  });

  group('replan', () {
    late FakeScheduler sched;
    late HydrationService h;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sched = FakeScheduler();
      h = HydrationService(sched)..clock = () => now;
      await h.load();
    });

    test('オフなら取り消すだけで予約しない', () async {
      expect(sched.cancelledRanges, isNotEmpty);
      expect(sched.scheduled, isEmpty);
    });

    test('オンにすると先に全部取り消してから張り直す', () async {
      await h.setEnabled(true);
      expect(sched.cancelledRanges.last, (2000, 2100));
      expect(sched.scheduled.keys.first, NotificationIds.hydrationFrom);
      expect(sched.scheduled[2000], DateTime(2026, 9, 11, 10, 30));
      expect(
        sched.scheduled.keys.every(
          (id) => id >= 2000 && id < NotificationIds.hydrationToExclusive,
        ),
        isTrue,
      );
    });

    test('間隔を変えると予約も変わる', () async {
      await h.setEnabled(true);
      await h.setInterval(90);
      expect(sched.scheduled[2000], DateTime(2026, 9, 11, 10, 30));
      expect(sched.scheduled[2001], DateTime(2026, 9, 11, 12, 0));
    });

    test('次に鳴る時刻', () async {
      expect(h.nextAt, isNull);
      await h.setEnabled(true);
      expect(h.nextAt, DateTime(2026, 9, 11, 10, 30));
    });
  });
}
