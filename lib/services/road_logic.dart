import 'dart:math' as math;

/// 道路の判定（前方衝突・車間距離・前の車の発進・後ろから来る車・信号の色・オービス）。
/// カメラやモデルに依らない純粋な計算だけを置き、テストで確かめる。
///
/// 似たアプリから機能を借りた（コードやデータは借りていない）:
/// - 前方衝突・車間距離: AONE Safe Driving / AutoBoy / openpilot の追従（車は操作せず知らせるだけ）
/// - 前の車の発進: カーナビ・ドラレコの「発進お知らせ」
/// - 後ろから来る車: WalkSafe（Dartmouth, 2012）
/// - 信号の色: Oko（AYES）
/// - オービス: カーナビの取締情報。ここでは OpenStreetMap の highway=speed_camera を使う

/// 検出した物ひとつ。座標は正立させた画像に対する 0〜1。
class RoadObject {
  const RoadObject(this.kind, this.score, this.left, this.top, this.right, this.bottom);
  final RoadKind kind;
  final double score;
  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;
  double get cx => (left + right) / 2;
  double get area => width * height;
}

enum RoadKind { person, bicycle, car, motorcycle, bus, truck, trafficLight, other }

extension RoadKindX on RoadKind {
  bool get isVehicle =>
      this == RoadKind.car ||
      this == RoadKind.bus ||
      this == RoadKind.truck ||
      this == RoadKind.motorcycle;
}

/// COCO SSD MobileNet v1 の出力クラス番号（0 始まり、labelmap の 1 行目 ??? を除いた位置）。
RoadKind kindFromCoco(int id) => switch (id) {
  0 => RoadKind.person,
  1 => RoadKind.bicycle,
  2 => RoadKind.car,
  3 => RoadKind.motorcycle,
  5 => RoadKind.bus,
  7 => RoadKind.truck,
  9 => RoadKind.trafficLight,
  _ => RoadKind.other,
};

/// 前の車（自分の車線にいる、いちばん大きい車）。
/// 車線は分からないので「画面の中央寄り・下寄り」で近似する。
RoadObject? pickLead(List<RoadObject> objs) {
  RoadObject? best;
  for (final o in objs) {
    if (!o.kind.isVehicle) continue;
    if (o.cx < 0.3 || o.cx > 0.7 || o.bottom < 0.45) continue;
    if (best == null || o.area > best.area) best = o;
  }
  return best;
}

/// いちばん大きい車（向きを問わない）。歩行モードの後方監視用。
RoadObject? pickLargestVehicle(List<RoadObject> objs) {
  RoadObject? best;
  for (final o in objs) {
    if (!o.kind.isVehicle) continue;
    if (best == null || o.area > best.area) best = o;
  }
  return best;
}

/// 見かけの幅の変化から TTC（衝突までの秒数）を出す。
/// 幅 w が dw/dt で大きくなっているとき、TTC ≈ w / (dw/dt)。
/// 距離を知らなくても出せるのが要点（単眼カメラの FCW の定番）。
class TtcTracker {
  TtcTracker({this.window = const Duration(milliseconds: 1200)});
  final Duration window;
  final List<(DateTime, double)> _hist = [];

  /// 追っている物を見失ったら呼ぶ。別の車の幅と混ぜないため。
  void reset() => _hist.clear();

  /// [width] は見かけの幅（0〜1）。十分な履歴が無い・近づいていないなら null。
  double? feed(double width, DateTime now) {
    if (_hist.isNotEmpty) {
      final jump = (width - _hist.last.$2).abs() / _hist.last.$2;
      // 1 フレームで 4 割も変わるのは別の車に乗り換えたとき。
      if (jump > 0.4) _hist.clear();
    }
    _hist.add((now, width));
    _hist.removeWhere((e) => now.difference(e.$1) > window);
    if (_hist.length < 3) return null;
    final first = _hist.first;
    final dt = now.difference(first.$1).inMilliseconds / 1000;
    if (dt < 0.4) return null;
    final rate = (width - first.$2) / dt;
    if (rate <= 0) return null;
    return width / rate;
  }
}

/// 前方衝突警報。TTC が [ttcBelow] 秒を下回り、前の車がある程度近い
/// （見かけの幅が [minWidth] 以上）ときに知らせる。自分が止まっているときは鳴らさない。
class FcwJudge {
  static const ttcBelow = 2.0;
  static const minWidth = 0.12;
  static const cooldown = Duration(seconds: 5);
  DateTime? _lastAt;
  int _streak = 0;

  bool feed({required double? ttc, required double width, double? speedKmh, required DateTime now}) {
    final moving = speedKmh == null || speedKmh > 10;
    final danger = moving && ttc != null && ttc < ttcBelow && width >= minWidth;
    _streak = danger ? _streak + 1 : 0;
    if (_streak < 2) return false;
    if (_lastAt != null && now.difference(_lastAt!) < cooldown) return false;
    _lastAt = now;
    return true;
  }
}

/// 見かけの幅から距離の目安。車幅 1.7m、カメラの横の画角 [fovDeg]（端末で違う・目安）。
double distanceFromWidth(double width, {double fovDeg = 65, double carWidthM = 1.7}) {
  final t = math.tan(fovDeg * math.pi / 360);
  return carWidthM / (width * 2 * t);
}

/// 車間距離（時間）の警告。40km/h 以上で、前の車までの時間が [below] 秒未満が
/// [hold] 続いたら。距離は目安なので、しきい値は短めに置く。
class HeadwayJudge {
  static const below = 0.8;
  static const minSpeed = 40.0;
  static const hold = Duration(seconds: 3);
  static const cooldown = Duration(seconds: 30);
  DateTime? _since, _lastAt;

  bool feed({required double? width, required double? speedKmh, required DateTime now}) {
    if (width == null || speedKmh == null || speedKmh < minSpeed) {
      _since = null;
      return false;
    }
    final gap = distanceFromWidth(width) / (speedKmh / 3.6);
    if (gap >= below) {
      _since = null;
      return false;
    }
    _since ??= now;
    if (now.difference(_since!) < hold) return false;
    if (_lastAt != null && now.difference(_lastAt!) < cooldown) return false;
    _lastAt = now;
    return true;
  }
}

/// 前の車の発進お知らせ。自分が止まって 3 秒たってから前の車の幅を覚え、
/// その 8 割を下回ったまま 1 秒続いたら一度だけ知らせる。自分が動いたら取り直す。
class LaunchJudge {
  static const stoppedFor = Duration(seconds: 3);
  static const shrinkTo = 0.8;
  static const hold = Duration(seconds: 1);
  DateTime? _stoppedSince, _shrunkSince;
  double? _baseline;
  bool _fired = false;

  bool feed({required double? leadWidth, required bool stopped, required DateTime now}) {
    if (!stopped) {
      _stoppedSince = _shrunkSince = _baseline = null;
      _fired = false;
      return false;
    }
    _stoppedSince ??= now;
    if (now.difference(_stoppedSince!) < stoppedFor) return false;
    if (_baseline == null) {
      _baseline = leadWidth;
      return false;
    }
    if (_fired) return false;
    // 前の車が画面から消えた（曲がった・遠ざかって検出できない）も「進んだ」。
    final gone = leadWidth == null || leadWidth < _baseline! * shrinkTo;
    if (!gone) {
      _shrunkSince = null;
      return false;
    }
    _shrunkSince ??= now;
    if (now.difference(_shrunkSince!) < hold) return false;
    _fired = true;
    return true;
  }
}

/// 後ろから来る車（歩行モード）。TTC が [ttcBelow] 秒未満、または見かけの幅が
/// 画面の [nearWidth] を超えたら知らせる。
class ApproachJudge {
  static const ttcBelow = 3.0;
  static const nearWidth = 0.45;
  static const cooldown = Duration(seconds: 4);
  DateTime? _lastAt;

  bool feed({required double? ttc, required double? width, required DateTime now}) {
    if (width == null) return false;
    final danger = (ttc != null && ttc < ttcBelow && width > 0.08) || width > nearWidth;
    if (!danger) return false;
    if (_lastAt != null && now.difference(_lastAt!) < cooldown) return false;
    _lastAt = now;
    return true;
  }
}

enum SignalColor { red, go, unknown }

/// 信号機の枠の中の画素（RGB を 3 つずつ並べたもの）から、点いている色を読む。
/// 明るく鮮やかな画素だけを数え、赤と青（青緑）の多いほう。どちらも少なければ不明。
SignalColor classifySignal(List<int> rgb) {
  var red = 0, go = 0;
  for (var i = 0; i + 2 < rgb.length; i += 3) {
    final r = rgb[i], g = rgb[i + 1], b = rgb[i + 2];
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    if (mx < 150 || mx - mn < 60) continue; // 暗い・くすんだ画素は数えない
    if (r == mx && r > g + 50) {
      red++;
    } else if (g == mx || (b == mx && g > r + 40)) {
      go++; // 日本の「青」信号は青緑
    }
  }
  final px = rgb.length ~/ 3;
  final need = math.max(4, px ~/ 50);
  if (red < need && go < need) return SignalColor.unknown;
  if (red >= go * 2) return SignalColor.red;
  if (go >= red * 2) return SignalColor.go;
  return SignalColor.unknown;
}

/// 2 点間の距離（m）。
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1, dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// 方位（度、北 0・時計回り）。
double bearing(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// 進行方向の前方 [within] m 以内・左右 [halfAngle]° 以内にある、いちばん近いオービス。
/// 戻り値は（番号, 距離 m）。向きが分からない（止まっている）ときは null。
(int, double)? cameraAhead(
  List<(double, double)> cams,
  double lat,
  double lon,
  double? heading, {
  double within = 600,
  double halfAngle = 30,
}) {
  if (heading == null || heading < 0) return null;
  (int, double)? best;
  for (var i = 0; i < cams.length; i++) {
    final d = haversine(lat, lon, cams[i].$1, cams[i].$2);
    if (d > within) continue;
    final diff = ((bearing(lat, lon, cams[i].$1, cams[i].$2) - heading + 540) % 360) - 180;
    if (diff.abs() > halfAngle) continue;
    if (best == null || d < best.$2) best = (i, d);
  }
  return best;
}
