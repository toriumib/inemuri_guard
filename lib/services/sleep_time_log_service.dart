import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一晩ぶんの「寝た・起きた」。
class SleepTimeEntry {
  final DateTime bed;
  final DateTime wake;
  const SleepTimeEntry({required this.bed, required this.wake});

  Duration get slept => wake.difference(bed);
  double get hours => slept.inMinutes / 60;

  /// 起きた日（時刻を落としたもの）。一晩を「起きた日」で識別する。
  DateTime get wakeDate => DateTime(wake.year, wake.month, wake.day);

  Map<String, dynamic> toJson() => {
    'b': bed.millisecondsSinceEpoch,
    'w': wake.millisecondsSinceEpoch,
  };

  static SleepTimeEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final b = j['b'], w = j['w'];
    if (b is! int || w is! int) return null;
    return SleepTimeEntry(
      bed: DateTime.fromMillisecondsSinceEpoch(b),
      wake: DateTime.fromMillisecondsSinceEpoch(w),
    );
  }
}

/// 睡眠時間の記録。就寝と起床の時刻だけを持つ。
///
/// [SleepLogService] とは別にしてある。あちらは「居眠りした・指摘された」
/// という点の出来事で、集計（unintendedSince・hourHistogram・
/// needsClinicalAttention）の分母になる。そこへ「寝た・起きた」を混ぜると、
/// 数え方がすべて狂う。これは日記であって、症状の記録ではない。
class SleepTimeLogService extends ChangeNotifier {
  static const _kEntries = 'sleep_time_entries';
  static const retentionDays = 90;
  static const _maxEntries = 200;

  /// 一晩の上限。これより長い「睡眠」は入力ミスとみなす。
  static const maxNight = Duration(hours: 20);

  final List<SleepTimeEntry> entries = [];

  /// テストで日付を固定するための差し替え口。
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    entries.clear();
    final cutoff = clock().subtract(const Duration(days: retentionDays));
    for (final raw in prefs.getStringList(_kEntries) ?? const []) {
      try {
        final e = SleepTimeEntry.fromJson(jsonDecode(raw));
        if (e != null && e.wake.isAfter(cutoff)) entries.add(e);
      } catch (_) {
        // 壊れた1件で全部を失わない。
      }
    }
    _sort();
    notifyListeners();
  }

  void _sort() => entries.sort((a, b) => b.wake.compareTo(a.wake));

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kEntries,
      entries.take(_maxEntries).map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// 記録する。同じ起床日の記録があれば置き換える。
  /// 0 以下、または [maxNight] より長いものは受け付けず false を返す。
  Future<bool> add({required DateTime bed, required DateTime wake}) async {
    final slept = wake.difference(bed);
    if (slept <= Duration.zero || slept > maxNight) return false;
    final entry = SleepTimeEntry(bed: bed, wake: wake);
    entries.removeWhere((e) => _sameDay(e.wakeDate, entry.wakeDate));
    entries.add(entry);
    _sort();
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> remove(SleepTimeEntry entry) async {
    entries.remove(entry);
    await _persist();
    notifyListeners();
  }

  /// 直近 [n] 日ぶん。添字 0 が n−1 日前、最後が今日。記録が無い日は null。
  List<double?> lastDays(int n, {DateTime? now}) {
    final today = _dateOnly(now ?? clock());
    return List.generate(n, (i) {
      final day = today.subtract(Duration(days: n - 1 - i));
      for (final e in entries) {
        if (_sameDay(e.wakeDate, day)) return e.hours;
      }
      return null;
    });
  }

  /// 直近 [n] 日の平均。記録が1件も無ければ null。記録の無い日は数えない。
  double? averageHours(int n, {DateTime? now}) {
    final xs = lastDays(n, now: now).whereType<double>().toList();
    if (xs.isEmpty) return null;
    return xs.reduce((a, b) => a + b) / xs.length;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
