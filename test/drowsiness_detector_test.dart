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
    // 顔が現れ、目が開いているところから始める。一度も開いた目を見て
    // いない「閉」は信じない（サングラス対策）ので、実機と同じ順にする。
    d.noteFaceSeen();
    d.ingestForTest(1.0);
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
  _postureTests();

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
    d.noteFaceSeen();
    d.ingestEyes(1.0, 1.0); // 開いた目を一度見てから
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
    d.noteFaceSeen();
    d.ingestForTest(1.0); // 開いた目を一度見てから
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

/// 頭の姿勢と、目が読めないとき（サングラス）。
/// 角度は「普段からのずれ」で見る。カメラの置き方で基準が変わるため。
void _postureTests() {
  late DrowsinessDetector d;
  late _Clock clock;

  setUp(() {
    d = DrowsinessDetector();
    clock = _Clock();
    d.clock = clock.call;
    d.setThresholdSeconds(5);
    d.noteFaceSeen();
  });

  /// 160ms 刻みで角度と目を流す。[open] は目の開き（既定は開いている）。
  void feedPose(int count, double pitch, double yaw, double roll, {double open = 1.0}) {
    for (var i = 0; i < count; i++) {
      clock.advance(const Duration(milliseconds: 160));
      d.ingestForTest(open);
      d.ingestPose(pitch, yaw, roll);
    }
  }

  test('普段の姿勢（下向き 15° のカメラ）では鳴らない', () {
    feedPose(80, -15, 0, 0); // 約13秒。基準が -15 になるだけ
    expect(d.alarmFiring, isFalse);
    expect(d.postureOffFor, Duration.zero);
  });

  test('頭が落ちて（普段から 30°）しきい値の秒数続いたら鳴る。理由は姿勢', () {
    feedPose(20, -10, 0, 0); // 普段
    feedPose(25, -40, 0, 0); // 約4秒 落ちる
    expect(d.alarmFiring, isFalse);
    feedPose(10, -40, 0, 0); // 通算 約5.6秒
    expect(d.alarmFiring, isTrue);
    expect(d.alarmCause, 'posture');
  });

  test('横倒し（roll）でも鳴る', () {
    feedPose(20, 0, 0, 0);
    feedPose(40, 0, 0, 35);
    expect(d.alarmFiring, isTrue);
  });

  test('姿勢で鳴ったら、姿勢が戻って 3 秒で止まる', () {
    feedPose(20, 0, 0, 0);
    feedPose(40, -40, 0, 0);
    expect(d.alarmFiring, isTrue);
    feedPose(10, 0, 0, 0); // 約1.6秒 戻す
    expect(d.alarmFiring, isTrue, reason: '戻した直後はまだ');
    feedPose(12, 0, 0, 0); // 通算 約3.5秒
    expect(d.alarmFiring, isFalse);
    expect(d.alarmCause, isNull);
  });

  test('落ちている最中に基準が追従しない', () {
    feedPose(20, 0, 0, 0);
    feedPose(200, -40, 0, 0); // 32秒 落ちたまま
    expect(d.alarmFiring, isTrue, reason: '基準が -40 に寄っていたら鳴らなくなる');
  });

  test('脇見は車モードのときだけ。2秒で知らせ、向き直ると消える', () {
    feedPose(20, 0, 0, 0);
    feedPose(25, 0, 45, 0); // 約4秒 横を向く（机）
    expect(d.lookAwayAlert, isFalse, reason: '机では横を見るのが普通');
    d.carMode = true;
    feedPose(10, 0, 0, 0); // 向き直る
    feedPose(25, 0, 45, 0); // 約4秒
    expect(d.lookAwayAlert, isTrue);
    expect(d.alarmFiring, isFalse, reason: '脇見はアラームではなく知らせ');
    feedPose(3, 0, 0, 0);
    expect(d.lookAwayAlert, isFalse);
  });

  test('車では手元を見る（俯き）も脇見。2秒で知らせ、机では知らせない', () {
    feedPose(20, 0, 0, 0);
    feedPose(15, -30, 0, 0); // 約2.4秒 手元を見る（机）
    expect(d.lookAwayAlert, isFalse, reason: '机では手元を見るのが普通');
    d.carMode = true;
    feedPose(10, 0, 0, 0); // 前を向く
    feedPose(10, -30, 0, 0); // 約1.6秒
    expect(d.lookAwayAlert, isFalse, reason: '2秒未満はまだ');
    feedPose(5, -30, 0, 0); // 通算 約2.4秒
    expect(d.lookAwayAlert, isTrue);
    expect(d.alarmFiring, isFalse);
  });

  test('車で上を見る（仰け反り）は手元見ではない', () {
    d.carMode = true;
    feedPose(20, 0, 0, 0);
    feedPose(15, 30, 0, 0);
    expect(d.lookAwayAlert, isFalse);
  });

  test('顔が現れてから一度も開いた目を見ていない「閉」では鳴らない（サングラス）', () {
    // 目の値は常に 0.02、10秒で「目が読めない」になる。姿勢は普段のまま。
    feedPose(70, 0, 0, 0, open: 0.02); // 約11秒
    expect(d.alarmFiring, isFalse);
    expect(d.eyesUnreadable, isTrue);
    expect(d.closedFor, Duration.zero);
  });

  test('目が読めなくても、頭が落ちれば鳴る', () {
    feedPose(70, 0, 0, 0, open: 0.02);
    expect(d.eyesUnreadable, isTrue);
    feedPose(40, -40, 0, 0, open: 0.02);
    expect(d.alarmFiring, isTrue);
    expect(d.alarmCause, 'posture');
  });

  test('開いた目を一度見れば、以後の閉じは普通に数える', () {
    feedPose(70, 0, 0, 0, open: 0.02);
    expect(d.eyesUnreadable, isTrue);
    feedPose(5, 0, 0, 0, open: 0.9); // サングラスを外した
    expect(d.eyesUnreadable, isFalse);
    feedPose(40, 0, 0, 0, open: 0.0); // 約6.4秒 閉じる
    expect(d.alarmFiring, isTrue);
    expect(d.alarmCause, 'eyes');
  });
}
