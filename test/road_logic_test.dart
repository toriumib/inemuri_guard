import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/road_logic.dart';

RoadObject car(double cx, double w, {double bottom = 0.8, RoadKind kind = RoadKind.car}) =>
    RoadObject(kind, 0.9, cx - w / 2, bottom - w * 0.8, cx + w / 2, bottom);

void main() {
  final t0 = DateTime(2026, 9, 23, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('前の車は中央・下寄りのいちばん大きい車。人や端の車は選ばない', () {
    final objs = [
      car(0.1, 0.4), // 端（隣の車線）
      car(0.5, 0.2),
      car(0.52, 0.1),
      const RoadObject(RoadKind.person, 0.9, 0.4, 0.3, 0.6, 0.9),
    ];
    expect(pickLead(objs)!.width, closeTo(0.2, 1e-9));
    expect(pickLead([car(0.5, 0.2, bottom: 0.3)]), isNull, reason: '上のほう＝遠い・対向の高架など');
  });

  test('30m 先から 10m/s で近づく車: 1 秒後（20m）の TTC はおよそ 2 秒', () {
    final t = TtcTracker();
    double? ttc;
    for (var i = 0; i <= 10; i++) {
      final dist = 30 - 10 * i / 10;
      ttc = t.feed(3.0 / dist, at(i * 100)); // 見かけの幅は距離に反比例
    }
    expect(ttc, closeTo(2.0, 0.1));
  });

  test('遠ざかる・変わらない車は TTC なし。別の車へ飛んだら履歴を捨てる', () {
    final t = TtcTracker();
    for (var i = 0; i <= 10; i++) {
      expect(t.feed(0.3 - 0.005 * i, at(i * 100)), isNull);
    }
    t.feed(0.6, at(1100)); // 別の車
    expect(t.feed(0.61, at(1200)), isNull, reason: '履歴が 2 点しかない');
  });

  test('前方衝突は TTC 2 秒未満が 2 回続いて一度。止まっているときは鳴らさない', () {
    final j = FcwJudge();
    expect(j.feed(ttc: 1.5, width: 0.2, speedKmh: 40, now: at(0)), isFalse);
    expect(j.feed(ttc: 1.5, width: 0.2, speedKmh: 40, now: at(200)), isTrue);
    expect(j.feed(ttc: 1.5, width: 0.2, speedKmh: 40, now: at(400)), isFalse, reason: '5 秒は黙る');
    final k = FcwJudge();
    k.feed(ttc: 1.0, width: 0.3, speedKmh: 3, now: at(0));
    expect(k.feed(ttc: 1.0, width: 0.3, speedKmh: 3, now: at(200)), isFalse);
  });

  test('距離の目安: 画角 65° で幅 0.2 ならおよそ 6.7m', () {
    expect(distanceFromWidth(0.2), closeTo(6.67, 0.1));
  });

  test('車間 0.8 秒未満が 3 秒続いたら。40km/h 未満は見ない', () {
    final j = HeadwayJudge();
    // 60km/h で幅 0.2（約 6.7m、0.4 秒）
    expect(j.feed(width: 0.2, speedKmh: 60, now: at(0)), isFalse);
    expect(j.feed(width: 0.2, speedKmh: 60, now: at(2900)), isFalse);
    expect(j.feed(width: 0.2, speedKmh: 60, now: at(3000)), isTrue);
    final k = HeadwayJudge();
    k.feed(width: 0.2, speedKmh: 30, now: at(0));
    expect(k.feed(width: 0.2, speedKmh: 30, now: at(5000)), isFalse);
  });

  test('発進お知らせ: 止まって 3 秒後の幅を基準に、8 割を切って 1 秒で一度', () {
    final j = LaunchJudge();
    expect(j.feed(leadWidth: 0.3, stopped: true, now: at(0)), isFalse);
    expect(j.feed(leadWidth: 0.3, stopped: true, now: at(3000)), isFalse); // 基準を取る
    expect(j.feed(leadWidth: 0.29, stopped: true, now: at(3500)), isFalse);
    expect(j.feed(leadWidth: 0.2, stopped: true, now: at(4000)), isFalse);
    expect(j.feed(leadWidth: 0.2, stopped: true, now: at(5000)), isTrue);
    expect(j.feed(leadWidth: 0.1, stopped: true, now: at(6000)), isFalse, reason: '一度だけ');
    j.feed(leadWidth: 0.1, stopped: false, now: at(7000)); // 自分も進んだ
    expect(j.feed(leadWidth: 0.3, stopped: true, now: at(8000)), isFalse);
  });

  test('発進お知らせ: 前の車が消えても（曲がった）知らせる', () {
    final j = LaunchJudge();
    j.feed(leadWidth: 0.3, stopped: true, now: at(0));
    j.feed(leadWidth: 0.3, stopped: true, now: at(3000));
    j.feed(leadWidth: null, stopped: true, now: at(3500));
    expect(j.feed(leadWidth: null, stopped: true, now: at(4600)), isTrue);
  });

  test('後ろから来る車: TTC 3 秒未満か、画面の半分近くまで大きい', () {
    final j = ApproachJudge();
    expect(j.feed(ttc: 5, width: 0.1, now: at(0)), isFalse);
    expect(j.feed(ttc: 2, width: 0.1, now: at(100)), isTrue);
    expect(j.feed(ttc: 2, width: 0.1, now: at(200)), isFalse, reason: '4 秒は黙る');
    expect(ApproachJudge().feed(ttc: null, width: 0.5, now: at(0)), isTrue);
  });

  List<int> fill(int n, int r, int g, int b) => [for (var i = 0; i < n; i++) ...[r, g, b]];

  test('信号の色: 赤・青緑・消灯（暗い）を分ける', () {
    expect(classifySignal([...fill(40, 240, 40, 30), ...fill(160, 30, 30, 30)]), SignalColor.red);
    expect(classifySignal([...fill(40, 30, 220, 180), ...fill(160, 30, 30, 30)]), SignalColor.go);
    expect(classifySignal(fill(200, 40, 40, 40)), SignalColor.unknown);
  });

  test('オービス: 進行方向の前 600m 以内だけ。後ろや横は数えない', () {
    // 北向きに走っている。北 300m・南 300m・東 300m に 1 つずつ。
    const lat = 35.0, lon = 139.0;
    final cams = [(35.0027, 139.0), (34.9973, 139.0), (35.0, 139.0033)];
    final hit = cameraAhead(cams, lat, lon, 0);
    expect(hit!.$1, 0);
    expect(hit.$2, closeTo(300, 5));
    expect(cameraAhead(cams, lat, lon, 180)!.$1, 1);
    expect(cameraAhead(cams, lat, lon, null), isNull, reason: '向きが分からない');
  });

  test('前の車は同じ車を追い続ける。隣の車線の大きい車に乗り移らない', () {
    final sel = LeadSelector();
    final a = car(0.5, 0.2);
    expect(identical(sel.pick([a]), a), isTrue);
    expect(sel.switched, isTrue, reason: '最初は選び直し');
    // 同じ車が少し大きくなり、横に大きい車（中央寄りの端）が現れる
    final a2 = car(0.51, 0.21);
    final big = car(0.66, 0.35);
    expect(identical(sel.pick([big, a2]), a2), isTrue);
    expect(sel.switched, isFalse);
  });

  test('TTC は 1 フレームの揺れで跳ねない（最小二乗）', () {
    final t = TtcTracker();
    double? ttc;
    // 実際は一定（近づいていない）。1 フレームおきに ±3% 揺れる
    for (var i = 0; i <= 12; i++) {
      final w = 0.2 * (i.isEven ? 1.03 : 0.97);
      ttc = t.feed(w, at(i * 100));
    }
    expect(ttc == null || ttc > 5, isTrue, reason: 'TTC=$ttc');
  });

  test('曲がっている最中は前方衝突を鳴らさない', () {
    final j = FcwJudge();
    j.feed(ttc: 1.0, width: 0.3, speedKmh: 40, turning: true, now: at(0));
    expect(j.feed(ttc: 1.0, width: 0.3, speedKmh: 40, turning: true, now: at(200)), isFalse);
  });

  /// 300×300 の路面。暗い灰色に、x=[l, l+4) と x=[r, r+4) の白線を画面下半分に引く。
  Uint8List road(int l, int r, {int size = 300}) {
    final px = Uint8List(size * size * 3);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = (y * size + x) * 3;
        final line = y > size ~/ 2 && ((x >= l && x < l + 4) || (x >= r && x < r + 4));
        final v = line ? 235 : 70;
        px[i] = v;
        px[i + 1] = v;
        px[i + 2] = v;
      }
    }
    return px;
  }

  test('車線の中央からのずれ: 真ん中なら 0、左の線に寄れば正', () {
    expect(estimateLaneOffset(road(60, 236), 300)!, closeTo(0, 0.05));
    // 線が右へずれて見える＝自分が左へ寄った
    expect(estimateLaneOffset(road(120, 290), 300)!, greaterThan(0.3));
    // 線が無い
    expect(estimateLaneOffset(road(-10, -10), 300), isNull);
  });

  test('車線逸脱: 普段の位置から 0.5 ずれて 1 秒で知らせる。60km/h 未満は見ない', () {
    final j = LdwJudge();
    for (var i = 0; i < 20; i++) {
      j.feed(offset: 0.1, speedKmh: 80, now: at(i * 100)); // 普段の位置を学ぶ
    }
    expect(j.feed(offset: 0.7, speedKmh: 80, now: at(2100)), isFalse);
    expect(j.feed(offset: 0.7, speedKmh: 80, now: at(3200)), isTrue);
    final k = LdwJudge();
    k.feed(offset: 0.0, speedKmh: 40, now: at(0));
    k.feed(offset: 0.9, speedKmh: 40, now: at(100));
    expect(k.feed(offset: 0.9, speedKmh: 40, now: at(2000)), isFalse);
  });

  test('DriveJudge: 近づく前の車で前方衝突を一度出す。車線逸脱は既定 OFF', () {
    final d = DriveJudge();
    final events = <RoadEvent>[];
    for (var i = 0; i <= 12; i++) {
      // 20m 先の車に 10m/s で近づく。見かけの幅は距離に反比例（2.0/距離）。
      // 1.2 秒後に 8m（本当の TTC 0.8 秒）。
      final dist = 20 - 10 * i / 10;
      events.addAll(d.feed(objects: [car(0.5, 2.0 / dist)], now: at(i * 100), speedKmh: 36));
    }
    expect(events.where((e) => e == RoadEvent.forwardCollision).length, 1);
    expect(d.laneDeparture, isFalse);
    expect(d.laneOffset, isNull);
  });

  test('遠い車を 1 回見失っても、同じ車として TTC を出し続ける', () {
    final d = DriveJudge();
    double? last;
    for (var i = 0; i <= 8; i++) {
      final dist = 30 - 10 * i * 0.25;
      // 2 回に 1 回だけ見つかる（遠い車でよくある）
      final objs = i.isOdd ? <RoadObject>[] : [car(0.5, 3.0 / dist)];
      d.feed(objects: objs, now: at(i * 250), speedKmh: 36);
      if (d.ttc != null) last = d.ttc;
    }
    // 最後は 2 秒後・10m 先（本当の TTC 1.0 秒）
    expect(last, isNotNull);
    expect(last!, closeTo(1.0, 0.3));
  });
}
