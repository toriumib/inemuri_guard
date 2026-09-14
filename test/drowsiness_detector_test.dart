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

  _occlusionTests();
  _eyesOpenToStopTests();

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

/// 眼鏡・マスク対策。
///
/// 眼鏡のレンズに光が反射すると片目だけ「閉」と読まれる。平均で見ると
/// そのたびに閉眼時間が積み上がって誤って鳴る。両目とも閉じたときだけ
/// 「閉」にする（[DrowsinessDetector.combineEyes]）。
void _occlusionTests() {
  late DrowsinessDetector d;
  late _Clock clock;

  setUp(() {
    d = DrowsinessDetector();
    clock = _Clock();
    d.clock = clock.call;
    d.setThresholdSeconds(5);
  });

  void feedEyes(int count, double l, double r) {
    for (var i = 0; i < count; i++) {
      clock.advance(const Duration(milliseconds: 160));
      d.ingestEyes(l, r);
    }
  }

  group('両目の合成', () {
    test('開いているほうを採る', () {
      expect(DrowsinessDetector.combineEyes(0.05, 0.95), 0.95);
      expect(DrowsinessDetector.combineEyes(0.95, 0.05), 0.95);
      expect(DrowsinessDetector.combineEyes(0.05, 0.05), 0.05);
    });

    test('片目だけ閉じて見えても鳴らない（レンズの反射・ウィンク）', () {
      feedEyes(70, 0.05, 0.95); // 約11秒。5秒設定なら平均なら鳴っていた
      expect(d.alarmFiring, isFalse);
    });

    test('両目とも閉じれば鳴る', () {
      feedEyes(70, 0.05, 0.05);
      expect(d.alarmFiring, isTrue);
    });
  });

  group('顔を見失ったとき', () {
    test('見失っている間の時間は閉眼に数えない', () {
      // 4秒閉じる → 顔が外れる → 4秒閉じる。続けて数えると8秒で鳴ってしまう。
      feedEyes(25, 0.05, 0.05); // 約4秒
      d.noteFaceLost();
      clock.advance(const Duration(seconds: 10));
      feedEyes(25, 0.05, 0.05); // 約4秒
      expect(d.alarmFiring, isFalse, reason: '外れていた10秒を閉眼に数えてはいけない');
    });

    test('鳴っている最中に顔を隠しても止まらない', () {
      feedEyes(70, 0.05, 0.05);
      expect(d.alarmFiring, isTrue);
      d.noteFaceLost();
      expect(d.alarmFiring, isTrue, reason: '顔を隠せば止まる、では困る');
    });

    test('3秒続いたら「長く見失っている」になる', () {
      d.noteFaceLost();
      expect(d.faceLostLong, isFalse);
      clock.advance(const Duration(seconds: 3));
      expect(d.faceLostLong, isTrue);
      // 顔が戻れば解除。
      d.noteFaceSeen();
      expect(d.faceLostLong, isFalse);
      expect(d.noFaceSeen, isFalse);
    });
  });
}

/// 「目を開けるまで止まらない」。1フレーム開いただけでは止めない。
void _eyesOpenToStopTests() {
  late DrowsinessDetector d;
  late _Clock clock;

  setUp(() {
    d = DrowsinessDetector();
    clock = _Clock();
    d.clock = clock.call;
    d.setThresholdSeconds(5);
  });

  void feed(int count, double openness) {
    for (var i = 0; i < count; i++) {
      clock.advance(const Duration(milliseconds: 160));
      d.ingestForTest(openness);
    }
  }

  test('目を1フレーム開いただけでは止まらない', () {
    feed(40, 0.0); // 約6.4秒 → 鳴る
    expect(d.alarmFiring, isTrue);
    feed(3, 1.0); // 約0.5秒だけ開く（寝ぼけて目を細めた）
    expect(d.alarmFiring, isTrue, reason: '一瞬開いただけで止めない');
    expect(d.openFor.inMilliseconds, greaterThan(0));
  });

  test('3秒開け続けたら止まる', () {
    feed(40, 0.0);
    // 平滑化（4フレーム平均）を抜けるぶんも含めて 3 秒以上。
    feed(25, 1.0); // 約4秒
    expect(d.alarmFiring, isFalse);
    expect(d.openFor, Duration.zero);
  });

  test('途中でまた閉じたら、開けている時間は振り出しに戻る', () {
    feed(40, 0.0);
    feed(12, 1.0); // 約2秒
    feed(6, 0.0); // また閉じる
    expect(d.alarmFiring, isTrue);
    expect(d.openFor, Duration.zero);
  });

  test('顔が消えても「開いている」には数えない', () {
    feed(40, 0.0);
    feed(12, 1.0);
    d.noteFaceLost();
    expect(d.openFor, Duration.zero);
    expect(d.alarmFiring, isTrue);
  });
}
