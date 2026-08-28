import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/sleep_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds the log directly so the pattern maths can be checked without waiting
/// real days. `add` accepts an explicit timestamp for exactly this reason.
Future<SleepLogService> _serviceWith(List<SleepEvent> events) async {
  SharedPreferences.setMockInitialValues({});
  final s = SleepLogService();
  await s.load();
  for (final e in events) {
    await s.add(e.type, note: e.note, at: e.time);
  }
  return s;
}

SleepEvent _ev(SleepEventType type, {required int daysAgo, int hour = 14}) {
  final now = DateTime.now();
  final d = now.subtract(Duration(days: daysAgo));
  return SleepEvent(time: DateTime(d.year, d.month, d.day, hour), type: type);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unintended vs planned', () {
    test('planned naps are excluded from the drowsiness pattern', () async {
      final s = await _serviceWith([
        _ev(SleepEventType.nap, daysAgo: 1),
        _ev(SleepEventType.nap, daysAgo: 2),
        _ev(SleepEventType.detected, daysAgo: 3),
      ]);
      // A nap is the app working, not a symptom — counting it would make
      // diligent users look unwell.
      expect(s.unintendedSince(const Duration(days: 7)).length, 1);
    });
  });

  group('daysAffectedLast', () {
    test('counts distinct days, not raw events', () async {
      final s = await _serviceWith([
        _ev(SleepEventType.detected, daysAgo: 1, hour: 10),
        _ev(SleepEventType.detected, daysAgo: 1, hour: 15),
        _ev(SleepEventType.pointedOut, daysAgo: 1, hour: 16),
        _ev(SleepEventType.detected, daysAgo: 2, hour: 14),
      ]);
      expect(s.daysAffectedLast(const Duration(days: 14)), 2);
    });
  });

  group('hourHistogram', () {
    test('buckets unintended events by hour of day', () async {
      final s = await _serviceWith([
        _ev(SleepEventType.detected, daysAgo: 1, hour: 14),
        _ev(SleepEventType.detected, daysAgo: 2, hour: 14),
        _ev(SleepEventType.pointedOut, daysAgo: 3, hour: 9),
        _ev(SleepEventType.nap, daysAgo: 3, hour: 14),
      ]);
      final h = s.hourHistogram(const Duration(days: 30));
      expect(h[14], 2, reason: 'the nap at 14h must not be counted');
      expect(h[9], 1);
      expect(h.fold<int>(0, (a, b) => a + b), 3);
    });
  });

  group('needsClinicalAttention', () {
    test('quiet by default', () async {
      final s = await _serviceWith([]);
      expect(s.needsClinicalAttention, isFalse);
    });

    test('a couple of bad days does not trigger it', () async {
      // Occasional sleepiness after a short night is normal; nagging about it
      // would train people to ignore the card that matters.
      final s = await _serviceWith([
        _ev(SleepEventType.detected, daysAgo: 1),
        _ev(SleepEventType.detected, daysAgo: 2),
      ]);
      expect(s.needsClinicalAttention, isFalse);
    });

    test('triggers once drowsiness spans five separate days', () async {
      final s = await _serviceWith([
        for (var d = 1; d <= 5; d++) _ev(SleepEventType.detected, daysAgo: d),
      ]);
      expect(s.needsClinicalAttention, isTrue);
    });

    test('many naps alone never trigger it', () async {
      final s = await _serviceWith([
        for (var d = 1; d <= 12; d++) _ev(SleepEventType.nap, daysAgo: d),
      ]);
      expect(s.needsClinicalAttention, isFalse);
    });

    test('old events fall outside the two-week window', () async {
      final s = await _serviceWith([
        for (var d = 20; d <= 24; d++) _ev(SleepEventType.detected, daysAgo: d),
      ]);
      expect(s.needsClinicalAttention, isFalse);
    });
  });

  group('symptoms', () {
    test('toggle on and off', () async {
      final s = await _serviceWith([]);
      await s.toggleSymptom('driving', true);
      expect(s.checkedSymptomIds.contains('driving'), isTrue);
      await s.toggleSymptom('driving', false);
      expect(s.checkedSymptomIds.contains('driving'), isFalse);
    });
  });
}
