import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/drive_nudge.dart';
import 'package:inemuri_guard/services/notification_service.dart';

/// 車に乗り続けていたら休憩を勧める判断のテスト。
///
/// 身体活動認識は「乗り物に乗っているか」しか教えてくれないので、
/// 鳴らしすぎを防ぐのはすべてこの側の判断（90秒・45分）。
/// native も権限も絡まない部分だけを確かめる。
class _Clock {
  DateTime now = DateTime(2026, 9, 17, 9);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Clock clock;
  late DriveNudgeService drive;
  late int suggested;

  setUp(() {
    clock = _Clock();
    drive = DriveNudgeService(NotificationService());
    drive.clock = clock.call;
    suggested = 0;
    drive.onSuggest = () => suggested++;
    // アプリを開いている想定。ポップアップの側で数える。
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  test('乗り始めて90秒までは勧めない', () {
    drive.debugEvent(true);
    clock.advance(const Duration(seconds: 89));
    drive.tick();
    expect(suggested, 0);
  });

  test('90秒乗り続けたら1回勧める', () {
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    expect(suggested, 1);
  });

  test('勧めたあとも乗り続けていても、鳴り続けない', () {
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    clock.advance(const Duration(hours: 2));
    drive.tick();
    drive.tick();
    expect(suggested, 1);
  });

  test('降りて乗り直しても、45分以内なら再勧誘しない', () {
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    clock.advance(const Duration(minutes: 20));
    drive.debugEvent(false);
    clock.advance(const Duration(minutes: 2));
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    expect(suggested, 1, reason: '前回の勧めから45分経っていない');
  });

  test('45分以上経ってからの乗り直しでは、また勧める', () {
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    clock.advance(DriveNudgeService.cooldown);
    drive.debugEvent(false);
    drive.debugEvent(true);
    clock.advance(DriveNudgeService.sustain);
    drive.tick();
    expect(suggested, 2);
  });

  test('降りたら数え直し。乗り直しから90秒を数える', () {
    drive.debugEvent(true);
    clock.advance(const Duration(seconds: 60));
    drive.debugEvent(false);
    clock.advance(const Duration(seconds: 31));
    drive.debugEvent(true);
    // 前の乗り時間（60秒）と合わせれば90秒を超えるが、
    // 降りた時点で振り出しなので、まだ勧めない。
    clock.advance(const Duration(seconds: 89));
    drive.tick();
    expect(suggested, 0);
    clock.advance(const Duration(seconds: 1));
    drive.tick();
    expect(suggested, 1);
  });
}
