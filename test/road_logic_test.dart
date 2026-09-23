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

  test('幅が 1 秒で 0.2→0.3 に増えると TTC はおよそ 3 秒', () {
    final t = TtcTracker();
    double? ttc;
    for (var i = 0; i <= 10; i++) {
      ttc = t.feed(0.2 + 0.01 * i, at(i * 100));
    }
    expect(ttc, closeTo(3.0, 0.1));
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
}
