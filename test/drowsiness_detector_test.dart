import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';

/// 実機で「しきい値を10秒にしても、目を閉じるとすぐ鳴る」という報告があった。
/// 原因は PERCLOS の分母を「集まったサンプル数」で見ていたこと。解析は
/// 約6回/秒なので 30 サンプルは5秒ぶんにしかならず、起動5秒後に1秒
/// 閉じただけで 6/30 = 0.2 ≥ 0.15 となって鳴っていた。
///
/// 時計を差し替えて、実際の経過時間を作って確かめる。
class _Clock {
  DateTime now = DateTime(2026, 1, 1, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

/// フレーム間隔と同じ 160ms 刻みで [count] 回ぶん流す。
void _feed(
  DrowsinessDetector d,
  _Clock clock,
  int count, {
  required double openness,
}) {
  for (var i = 0; i < count; i++) {
    clock.advance(const Duration(milliseconds: 160));
    d.ingestForTest(openness);
  }
}

void main() {
  late DrowsinessDetector d;
  late _Clock clock;

  setUp(() {
    d = DrowsinessDetector();
    clock = _Clock();
    d.clock = clock.call;
  });

  group('連続して閉じた時間で鳴らす', () {
    test('しきい値に届くまでは鳴らない', () {
      d.setThresholdSeconds(10);
      // 9秒ぶん閉じる（160ms × 56 ≒ 9.0秒）。
      _feed(d, clock, 56, openness: 0.0);
      expect(d.alarmFiring, isFalse, reason: '10秒の設定で9秒では鳴らないこと');
    });

    test('しきい値を超えたら鳴る', () {
      d.setThresholdSeconds(10);
      _feed(d, clock, 70, openness: 0.0); // 約11秒
      expect(d.alarmFiring, isTrue);
    });

    test('5秒に設定すれば5秒で鳴る', () {
      d.setThresholdSeconds(5);
      _feed(d, clock, 25, openness: 0.0); // 約4秒
      expect(d.alarmFiring, isFalse);
      _feed(d, clock, 15, openness: 0.0); // 通算 約6.4秒
      expect(d.alarmFiring, isTrue);
    });
  });

  group('PERCLOS', () {
    test('1分ぶん貯まる前は、割合が高くても鳴らさない', () {
      // これが実機で起きていた壊れ方そのもの。
      // しきい値は十分長くしておき、連続閉眼では鳴らないようにする。
      d.setThresholdSeconds(60);
      _feed(d, clock, 24, openness: 1.0); // 約4秒、開けている
      _feed(d, clock, 12, openness: 0.0); // 約2秒、閉じる
      // 12/36 = 0.33 で 0.15 を大きく超えるが、まだ6秒ぶんしかない。
      expect(
        d.alarmFiring,
        isFalse,
        reason: '直近1分ぶん貯まるまで PERCLOS で鳴らしてはいけない',
      );
    });

    test('1分経ったあとは、重いまばたきの蓄積で鳴る', () {
      d.setThresholdSeconds(60);
      // 1分ぶん、ほぼ開けたまま流す（約6回/秒 × 60秒）。
      _feed(d, clock, 360, openness: 1.0);
      expect(d.alarmFiring, isFalse);
      // ここから閉じ気味の値を混ぜて、直近1分の割合を押し上げる。
      _feed(d, clock, 80, openness: 0.0);
      expect(d.alarmFiring, isTrue);
    });

    test('一度 PERCLOS で鳴ったら、その1分ぶんは使い切る', () {
      d.setThresholdSeconds(60);
      _feed(d, clock, 360, openness: 1.0);
      _feed(d, clock, 80, openness: 0.0);
      expect(d.alarmFiring, isTrue);
      expect(d.perclos, 0, reason: '鳴らした窓を残すと、止めた直後にまた鳴る');
    });
  });

  group('スヌーズ', () {
    test('スヌーズ中は閉じ続けても鳴らない', () {
      d.setThresholdSeconds(5);
      d.snooze();
      _feed(d, clock, 60, openness: 0.0); // 約9.6秒
      expect(d.alarmFiring, isFalse);
    });

    test('スヌーズが明ければまた鳴る', () {
      d.setThresholdSeconds(5);
      d.snooze();
      clock.advance(const Duration(minutes: 4));
      _feed(d, clock, 60, openness: 0.0);
      expect(d.alarmFiring, isTrue);
    });
  });
}
