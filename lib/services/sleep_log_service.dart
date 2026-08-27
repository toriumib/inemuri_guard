import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SleepEventType {
  /// The camera/mic sensors raised the alarm.
  detected,

  /// The user tapped "指摘された" — someone else noticed them dozing.
  /// This matters more than a sensor hit: it means the drowsiness was
  /// visible to other people, which is a stronger real-world signal.
  pointedOut,

  /// A deliberate nap finished.
  nap,
}

extension SleepEventTypeX on SleepEventType {
  String get label => switch (this) {
    SleepEventType.detected => 'アプリが検知',
    SleepEventType.pointedOut => '人から指摘された',
    SleepEventType.nap => '計画仮眠',
  };

  String get storageKey => name;

  static SleepEventType fromKey(String key) => SleepEventType.values.firstWhere(
    (t) => t.name == key,
    orElse: () => SleepEventType.detected,
  );
}

class SleepEvent {
  final DateTime time;
  final SleepEventType type;
  final String? note;

  SleepEvent({required this.time, required this.type, this.note});

  Map<String, dynamic> toJson() => {
    't': time.toIso8601String(),
    'k': type.storageKey,
    if (note != null) 'n': note,
  };

  factory SleepEvent.fromJson(Map<String, dynamic> j) => SleepEvent(
    time: DateTime.parse(j['t'] as String),
    type: SleepEventTypeX.fromKey(j['k'] as String),
    note: j['n'] as String?,
  );
}

/// Long-term log of drowsiness events, kept so patterns over weeks are
/// visible rather than just "today's count".
///
/// This is a diary, NOT a diagnostic instrument. Nothing here scores the
/// user against a validated clinical scale, and nothing concludes that a
/// person has any condition — see [needsClinicalAttention], which only ever
/// decides whether to *suggest talking to a doctor*.
class SleepLogService extends ChangeNotifier {
  static const _kEvents = 'sleep_events';
  static const _kSymptoms = 'sleep_symptoms';

  /// Keep roughly three months. Long enough to see a pattern, short enough
  /// that the prefs blob stays small.
  static const retentionDays = 90;
  static const _maxEvents = 1000;

  final List<SleepEvent> events = [];
  Set<String> checkedSymptomIds = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kEvents) ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: retentionDays));
    events
      ..clear()
      ..addAll(
        raw
            .map(
              (s) => SleepEvent.fromJson(jsonDecode(s) as Map<String, dynamic>),
            )
            .where((e) => e.time.isAfter(cutoff)),
      );
    events.sort((a, b) => b.time.compareTo(a.time));
    checkedSymptomIds = (prefs.getStringList(_kSymptoms) ?? []).toSet();
    notifyListeners();
  }

  Future<void> add(SleepEventType type, {String? note, DateTime? at}) async {
    events.insert(
      0,
      SleepEvent(time: at ?? DateTime.now(), type: type, note: note),
    );
    while (events.length > _maxEvents) {
      events.removeLast();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(SleepEvent event) async {
    events.remove(event);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kEvents,
      events.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> toggleSymptom(String id, bool checked) async {
    if (checked) {
      checkedSymptomIds.add(id);
    } else {
      checkedSymptomIds.remove(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSymptoms, checkedSymptomIds.toList());
    notifyListeners();
  }

  // ── derived views ────────────────────────────────────────────────

  List<SleepEvent> since(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return events.where((e) => e.time.isAfter(cutoff)).toList();
  }

  /// Unintended drowsiness only — planned naps are the app working as
  /// intended and must not inflate the pattern.
  List<SleepEvent> unintendedSince(Duration window) =>
      since(window).where((e) => e.type != SleepEventType.nap).toList();

  int countLast(Duration window, SleepEventType type) =>
      since(window).where((e) => e.type == type).length;

  /// How many distinct calendar days in the window had unintended drowsiness.
  int daysAffectedLast(Duration window) => unintendedSince(
    window,
  ).map((e) => DateTime(e.time.year, e.time.month, e.time.day)).toSet().length;

  /// Counts per hour of day (0-23) for unintended events, so the log can show
  /// *when* it happens — a post-lunch cluster reads very differently from
  /// all-day sleepiness.
  List<int> hourHistogram(Duration window) {
    final buckets = List<int>.filled(24, 0);
    for (final e in unintendedSince(window)) {
      buckets[e.time.hour]++;
    }
    return buckets;
  }

  /// Whether the app should surface the "consider seeing a doctor" card.
  ///
  /// Deliberately conservative and pattern-based, not a score: it triggers on
  /// *persistence* (drowsiness on many separate days over two weeks), because
  /// occasional sleepiness after a bad night is normal and shouldn't nag.
  bool get needsClinicalAttention {
    const window = Duration(days: 14);
    return daysAffectedLast(window) >= 5 ||
        unintendedSince(window).length >= 10;
  }
}
