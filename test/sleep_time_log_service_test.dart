import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/sleep_time_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 11, 9);
  late SleepTimeLogService s;

  DateTime d(int daysAgo, int hour, [int minute = 0]) {
    final base = today.subtract(Duration(days: daysAgo));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = SleepTimeLogService()..clock = () => today;
    await s.load();
  });

  test('23:00 に寝て 6:30 に起きたら 7.5 時間', () async {
    final ok = await s.add(bed: d(1, 23), wake: d(0, 6, 30));
    expect(ok, isTrue);
    expect(s.entries.single.hours, 7.5);
  });

  test('同じ起床日は置き換える', () async {
    await s.add(bed: d(1, 23), wake: d(0, 6));
    await s.add(bed: d(1, 22), wake: d(0, 6));
    expect(s.entries.length, 1);
    expect(s.entries.single.hours, 8);
  });

  test('0 以下や 20 時間超は受け付けない', () async {
    expect(await s.add(bed: d(0, 6), wake: d(0, 6)), isFalse);
    expect(await s.add(bed: d(0, 7), wake: d(0, 6)), isFalse);
    expect(await s.add(bed: d(2, 6), wake: d(0, 6)), isFalse);
    expect(s.entries, isEmpty);
  });

  test('91 日前の記録は読み込みで落ちる', () async {
    await s.add(bed: d(92, 23), wake: d(91, 6));
    await s.add(bed: d(1, 23), wake: d(0, 6));
    final t = SleepTimeLogService()..clock = () => today;
    await t.load();
    expect(t.entries.length, 1);
    expect(t.entries.single.wakeDate, DateTime(2026, 9, 11));
  });

  test('直近7日は7枠で、無い日は null', () async {
    await s.add(bed: d(1, 23), wake: d(0, 7)); // 今日 8h
    await s.add(bed: d(3, 0), wake: d(3, 6)); // 3日前 6h（0時に寝て6時起き）
    final week = s.lastDays(7, now: today);
    expect(week.length, 7);
    expect(week.last, 8);
    expect(week[3], 6);
    expect(week.where((h) => h == null).length, 5);
  });

  test('平均は記録の無い日を数えない', () async {
    await s.add(bed: d(1, 23), wake: d(0, 7)); // 8h
    await s.add(bed: d(3, 0), wake: d(3, 6)); // 6h
    expect(s.averageHours(7, now: today), 7);
    expect(SleepTimeLogService().averageHours(7, now: today), isNull);
  });

  test('消せる', () async {
    await s.add(bed: d(1, 23), wake: d(0, 7));
    await s.remove(s.entries.single);
    expect(s.entries, isEmpty);
  });
}
