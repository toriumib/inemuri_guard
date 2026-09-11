import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_scheduler.dart';

/// 水分補給のリマインダー。決めた間隔・時間帯で「一口」をすすめる。
///
/// ## 先に予約しておく方式
/// 通知が鳴ったときに Dart は動いていない（プラグインは配達だけをする）。
/// だから「鳴ったら次を予約」はできない。`periodicallyShow` は時間帯を
/// 守れない。残る手は、**今日の残りと明日ぶんを先にまとめて予約**し、
/// アプリが前面に来るたびに張り直すこと（[replan]）。
///
/// inexact なので数分遅れる。メーカーの省電力で落ちることもある。
/// 設定画面にそう書いてある。
class HydrationService extends ChangeNotifier {
  HydrationService(this._scheduler);

  final NotificationScheduler _scheduler;

  static const _kOn = 'hydration_on';
  static const _kInterval = 'hydration_interval_min';
  static const _kFrom = 'hydration_from_hour';
  static const _kTo = 'hydration_to_hour';

  static const intervals = [30, 45, 60, 90];

  bool enabled = false;
  int intervalMinutes = 45;
  int fromHour = 9;
  int toHour = 18;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_kOn) ?? false;
    intervalMinutes = prefs.getInt(_kInterval) ?? 45;
    fromHour = prefs.getInt(_kFrom) ?? 9;
    toHour = prefs.getInt(_kTo) ?? 18;
    await replan();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOn, enabled);
    await prefs.setInt(_kInterval, intervalMinutes);
    await prefs.setInt(_kFrom, fromHour);
    await prefs.setInt(_kTo, toHour);
  }

  Future<void> setEnabled(bool on) async {
    enabled = on;
    await _persist();
    await replan();
    notifyListeners();
  }

  Future<void> setInterval(int minutes) async {
    intervalMinutes = minutes;
    await _persist();
    await replan();
    notifyListeners();
  }

  Future<void> setHours({int? from, int? to}) async {
    fromHour = (from ?? fromHour).clamp(0, 23);
    toHour = (to ?? toHour).clamp(0, 23);
    await _persist();
    await replan();
    notifyListeners();
  }

  /// これから鳴らす時刻の一覧。純関数。
  ///
  /// 今日の [fromHour]:00 から [intervalMinutes] 刻みで [toHour]:00 の手前まで、
  /// 過ぎたものは飛ばす。続けて明日ぶん。上限 [max] 件（通知 id の幅）。
  /// [fromHour] ≥ [toHour] なら空（時間帯が成立しない）。
  static List<DateTime> planSlots({
    required DateTime now,
    required int intervalMinutes,
    required int fromHour,
    required int toHour,
    int max = NotificationIds.hydrationToExclusive - NotificationIds.hydrationFrom,
  }) {
    if (fromHour >= toHour || intervalMinutes <= 0) return const [];
    final out = <DateTime>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var day = 0; day < 2 && out.length < max; day++) {
      final base = today.add(Duration(days: day));
      final end = DateTime(base.year, base.month, base.day, toHour);
      var t = DateTime(base.year, base.month, base.day, fromHour);
      // 開始時刻そのものでは鳴らさない。1間隔たってから。
      t = t.add(Duration(minutes: intervalMinutes));
      while (t.isBefore(end) && out.length < max) {
        if (t.isAfter(now)) out.add(t);
        t = t.add(Duration(minutes: intervalMinutes));
      }
    }
    return out;
  }

  /// 予約を全部取り消して、今の設定で張り直す。
  /// 復帰時・設定変更時・起動時に呼ぶ。
  Future<void> replan() async {
    await _scheduler.cancelRange(
      NotificationIds.hydrationFrom,
      NotificationIds.hydrationToExclusive,
    );
    if (!enabled) return;
    final slots = planSlots(
      now: clock(),
      intervalMinutes: intervalMinutes,
      fromHour: fromHour,
      toHour: toHour,
    );
    for (var i = 0; i < slots.length; i++) {
      await _scheduler.scheduleAt(
        id: NotificationIds.hydrationFrom + i,
        channel: NotificationChannels.hydration,
        title: '水分補給',
        body: 'そろそろ水を一口。',
        at: slots[i],
      );
    }
  }

  /// 次に鳴る時刻。画面に出すためだけ。
  DateTime? get nextAt {
    if (!enabled) return null;
    final slots = planSlots(
      now: clock(),
      intervalMinutes: intervalMinutes,
      fromHour: fromHour,
      toHour: toHour,
      max: 1,
    );
    return slots.isEmpty ? null : slots.first;
  }
}
