import 'package:inemuri_guard/services/notification_scheduler.dart';

/// 「何番を・いつ予約したか」を数えるだけの偽物。
class FakeScheduler implements NotificationScheduler {
  final Map<int, DateTime> scheduled = {};
  final List<int> cancelled = [];
  final List<(int, int)> cancelledRanges = [];

  @override
  Future<void> scheduleAt({
    required int id,
    required String channel,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    scheduled[id] = at;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelRange(int from, int toExclusive) async {
    cancelledRanges.add((from, toExclusive));
    scheduled.removeWhere((id, _) => id >= from && id < toExclusive);
  }
}
