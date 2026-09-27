import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inemuri_guard/services/road_logic.dart';
import 'package:inemuri_guard/services/stats_service.dart';
import 'package:inemuri_guard/l10n/generated/app_localizations_en.dart';
import 'package:inemuri_guard/l10n/generated/app_localizations_ja.dart';
import 'package:inemuri_guard/widgets/road_overlay.dart';

DateTime at(int ms) => DateTime(2026).add(Duration(milliseconds: ms));
RoadObject user({
  RoadKind kind = RoadKind.person,
  double cx = 0.5,
  double score = 0.9,
  double top = 0.35,
  double bottom = 0.8,
}) => RoadObject(kind, score, cx - 0.05, top, cx + 0.05, bottom);

void main() {
  for (final kind in [RoadKind.person, RoadKind.bicycle, RoadKind.motorcycle]) {
    test('confirms $kind over time, then rate limits', () {
      final j = RoadUserJudge();
      final o = [user(kind: kind)];
      expect(j.feed(objects: o, now: at(0)), isFalse);
      expect(j.feed(objects: o, now: at(250)), isFalse);
      expect(j.feed(objects: o, now: at(500)), isTrue);
      for (var ms = 750; ms < 8500; ms += 250) {
        expect(j.feed(objects: o, now: at(ms)), isFalse);
      }
      expect(j.feed(objects: o, now: at(8500)), isTrue);
    });
  }

  test('three fast observations are not enough', () {
    final j = RoadUserJudge();
    for (final ms in [0, 50, 100, 200, 400]) {
      expect(j.feed(objects: [user()], now: at(ms)), isFalse);
    }
    expect(j.feed(objects: [user()], now: at(500)), isTrue);
  });

  test('ignores roadside, distant, weak, irrelevant and invalid boxes', () {
    for (final o in [
      user(cx: 0.15),
      user(cx: 0.85),
      user(score: 0.59),
      user(top: 0.65, bottom: 0.8),
      user(bottom: 0.55),
      user(kind: RoadKind.car),
      user(kind: RoadKind.trafficLight),
      user(score: double.nan),
      user(cx: double.infinity),
      user(top: 0.9),
      user(top: -0.1),
      user(bottom: 1.1),
      const RoadObject(RoadKind.person, 0.9, 0.6, 0.3, 0.4, 0.8),
    ]) {
      final j = RoadUserJudge();
      for (var ms = 0; ms <= 1500; ms += 250) {
        expect(j.feed(objects: [o], now: at(ms)), isFalse);
      }
    }
  });

  test('stopped, invalid speed and turning reset confirmation', () {
    for (final speed in [0.0, 4.9, -1.0, double.nan, double.infinity]) {
      final j = RoadUserJudge();
      for (final ms in [0, 250, 500]) {
        expect(
          j.feed(objects: [user()], speedKmh: speed, now: at(ms)),
          isFalse,
        );
      }
    }
    final j = RoadUserJudge();
    j.feed(objects: [user()], now: at(0));
    j.feed(objects: [user()], now: at(250));
    expect(j.feed(objects: [user()], turning: true, now: at(500)), isFalse);
    expect(j.feed(objects: [user()], now: at(750)), isFalse);
    expect(j.feed(objects: [user()], now: at(1000)), isFalse);
    expect(j.feed(objects: [user()], now: at(1250)), isTrue);
  });

  test(
    'missing frame, long gap, repeated and backwards time reset evidence',
    () {
      for (final interruption in [500, 2000, 250, 100]) {
        final j = RoadUserJudge();
        j.feed(objects: [user()], now: at(0));
        j.feed(objects: [user()], now: at(250));
        expect(
          j.feed(
            objects: interruption == 500 ? [] : [user()],
            now: at(interruption),
          ),
          isFalse,
        );
        expect(j.feed(objects: [user()], now: at(interruption + 250)), isFalse);
      }
    },
  );

  test('different road users cannot share confirmation history', () {
    final j = RoadUserJudge();
    for (var i = 0; i < 8; i++) {
      expect(
        j.feed(
          objects: [user(cx: i.isEven ? 0.4 : 0.6)],
          now: at(i * 250),
        ),
        isFalse,
      );
    }
    final k = RoadUserJudge();
    for (var i = 0; i < 8; i++) {
      expect(
        k.feed(
          objects: [user(kind: i.isEven ? RoadKind.person : RoadKind.bicycle)],
          now: at(i * 250),
        ),
        isFalse,
      );
    }
  });

  test('keeps tracked user when another larger detection appears', () {
    final j = RoadUserJudge();
    j.feed(objects: [user(cx: 0.4)], now: at(0));
    j.feed(objects: [user(cx: 0.41), user(cx: 0.6, top: 0.1)], now: at(250));
    expect(
      j.feed(objects: [user(cx: 0.42), user(cx: 0.6, top: 0.1)], now: at(500)),
      isTrue,
    );
  });

  test(
    'DriveJudge is opt-in and emits warning without treating person as lead',
    () {
      final j = DriveJudge();
      for (final ms in [0, 250, 500]) {
        expect(j.feed(objects: [user()], now: at(ms)), isEmpty);
      }
      j.roadUserWarning = true;
      j.feed(objects: [user()], now: at(750));
      j.feed(objects: [user()], now: at(1000));
      expect(j.feed(objects: [user()], now: at(1250)), [
        RoadEvent.roadUserAhead,
      ]);
      expect(j.lead, isNull);
      j.roadUserWarning = false;
      expect(j.feed(objects: [user()], now: at(1500)), isEmpty);
      j.roadUserWarning = true;
      expect(j.feed(objects: [user()], now: at(1750)), isEmpty);
    },
  );

  test('collision warning precedes simultaneous road-user warning', () {
    final j = DriveJudge()..roadUserWarning = true;
    List<RoadEvent> events = [];
    final widths = [0.2, 0.24, 0.3, 0.4];
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i];
      events = j.feed(
        objects: [
          RoadObject(RoadKind.car, 0.95, 0.5 - w / 2, 0.4, 0.5 + w / 2, 0.85),
          if (i > 0) user(),
        ],
        speedKmh: 40,
        now: at(i * 250),
      );
    }
    expect(events, contains(RoadEvent.roadUserAhead));
    expect(events.first, RoadEvent.forwardCollision);
  });

  test('preference defaults off and survives reload', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService();
    await stats.load();
    expect(stats.roadUserWarning, isFalse);
    await stats.setRoadUserWarning(true);
    final loaded = StatsService();
    await loaded.load();
    expect(loaded.roadUserWarning, isTrue);
    await loaded.setRoadUserWarning(false);
    await stats.load();
    expect(stats.roadUserWarning, isFalse);
    stats.dispose();
    loaded.dispose();
  });

  test('warning has Japanese and English text for banner and speech', () {
    expect(
      roadEventText(AppLocalizationsJa(), RoadEvent.roadUserAhead),
      contains('歩行者'),
    );
    expect(
      roadEventText(AppLocalizationsEn(), RoadEvent.roadUserAhead),
      contains('rider'),
    );
  });
}
