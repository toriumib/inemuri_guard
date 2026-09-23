import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/speed_limit_service.dart';

void main() {
  test('maxspeed は数字だけ読む。区分や none は推測しない', () {
    expect(SpeedLimitService.parseMaxspeed('40'), 40);
    expect(SpeedLimitService.parseMaxspeed('60 km/h'), 60);
    expect(SpeedLimitService.parseMaxspeed('30 mph'), 48);
    expect(SpeedLimitService.parseMaxspeed('JP:urban'), isNull);
    expect(SpeedLimitService.parseMaxspeed('none'), isNull);
    expect(SpeedLimitService.parseMaxspeed('40;60'), isNull);
  });

  test('区画は約 2km 四方。近い 2 点は同じ区画になる', () {
    expect(
      SpeedLimitService.tileKey(35.4431, 139.6380),
      SpeedLimitService.tileKey(35.4439, 139.6389),
    );
    expect(SpeedLimitService.tileKey(-0.001, -0.001), '-1,-1');
  });

  test('Overpass の応答から道路と制限速度を取り、いちばん近い道を選ぶ', () {
    const body = '''
{"elements":[
 {"type":"way","tags":{"highway":"primary","maxspeed":"50"},
  "geometry":[{"lat":35.0000,"lon":139.0000},{"lat":35.0000,"lon":139.0100}]},
 {"type":"way","tags":{"highway":"residential","maxspeed":"30"},
  "geometry":[{"lat":35.0010,"lon":139.0000},{"lat":35.0010,"lon":139.0100}]},
 {"type":"way","tags":{"highway":"service","maxspeed":"signals"},
  "geometry":[{"lat":35.0,"lon":139.0},{"lat":35.1,"lon":139.1}]}
]}''';
    final ways = SpeedLimitService.parseOverpass(body);
    expect(ways.length, 2);
    // 50 の道から約 11m 北
    expect(SpeedLimitService.nearestLimit(ways, 35.0001, 139.005, 25), 50);
    // 30 の道の上
    expect(SpeedLimitService.nearestLimit(ways, 35.0010, 139.005, 25), 30);
    // どちらからも約 55m 離れている → 不明
    expect(SpeedLimitService.nearestLimit(ways, 35.0005, 139.005, 25), isNull);
  });

  test('超過は +5km/h が 3 秒続いて一度だけ。60 秒は黙る', () {
    final j = OverspeedJudge();
    final t0 = DateTime(2026, 9, 23, 12);
    expect(j.feed(44, 40, t0), isFalse, reason: '+5 以内は超過にしない');
    expect(j.feed(50, 40, t0), isFalse);
    expect(j.feed(50, 40, t0.add(const Duration(seconds: 2))), isFalse);
    expect(j.feed(50, 40, t0.add(const Duration(seconds: 3))), isTrue);
    expect(j.feed(50, 40, t0.add(const Duration(seconds: 30))), isFalse);
    expect(j.feed(50, 40, t0.add(const Duration(seconds: 64))), isTrue);
    expect(j.feed(50, null, t0.add(const Duration(seconds: 200))), isFalse,
        reason: '制限不明では鳴らさない');
  });

  test('オービスは highway=speed_camera の点だけ拾う', () {
    const body = '''
{"elements":[
 {"type":"node","lat":35.1,"lon":139.1,"tags":{"highway":"speed_camera"}},
 {"type":"node","lat":35.2,"lon":139.2,"tags":{"highway":"traffic_signals"}},
 {"type":"way","tags":{"highway":"primary","maxspeed":"50"},
  "geometry":[{"lat":35.0,"lon":139.0},{"lat":35.0,"lon":139.01}]}
]}''';
    expect(SpeedLimitService.parseSpeedCameras(body), [(35.1, 139.1)]);
    expect(SpeedLimitService.parseOverpass(body).length, 1, reason: '点は道路に数えない');
  });
}
