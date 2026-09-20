import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/voice_stop.dart';

/// 声で止める語の照合。認識器は端末依存なので、照合だけを固定する。
void main() {
  const speech = MethodChannel('plugin.csdcorp.com/speech_to_text');
  const permission = MethodChannel('flutter.baseflow.com/permissions/methods');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permission,
      (_) async => 1,
    );
  });
  tearDown(() async {
    await VoiceStop.instance.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(speech, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(permission, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'dismissal during locale discovery cannot start listening later',
    () async {
      final queried = Completer<void>();
      final locales = Completer<List<String>>();
      var listens = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(speech, (
        call,
      ) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'locales') {
          queried.complete();
          return locales.future;
        }
        if (call.method == 'listen') listens++;
        return true;
      });
      final start = VoiceStop.instance.start();
      await queried.future;
      await VoiceStop.instance.stop();
      locales.complete(['ja_JP:Japanese', 'en_US:English']);
      await start;
      expect(VoiceStop.instance.listening, false);
      expect(listens, 0);
    },
  );

  test(
    'English device sends the supported regional locale to speech SDK',
    () async {
      binding.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      String? listenedLocale;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(speech, (
        call,
      ) async {
        if (call.method == 'locales') {
          return ['en_GB:English UK', 'ja_JP:Japanese', 'en_US:English US'];
        }
        if (call.method == 'listen') {
          listenedLocale = (call.arguments as Map)['localeId'] as String?;
        }
        return true;
      });
      await VoiceStop.instance.start();
      expect(listenedLocale, 'en_GB');
      expect(VoiceStop.instance.listening, true);
      await VoiceStop.instance.stop();
    },
  );
  test('「起きた」「止めて」系は止める', () {
    for (final s in [
      '起きた',
      'おきた よ',
      'もう 起きて',
      '止めて',
      'ストップ',
      'Stop it',
      'I’m awake',
      'I am awake',
      '大丈夫です',
    ]) {
      expect(VoiceStop.matches(s), isTrue, reason: s);
    }
  });

  test('関係ない言葉では止めない', () {
    for (final s in [
      '',
      'おはよう',
      '眠い',
      'テレビ 消して',
      'unstoppable',
      'busstop',
      'stopping',
      'awaken',
    ]) {
      expect(VoiceStop.matches(s), isFalse, reason: s);
    }
  });

  test('speech locale follows the supported language and region', () {
    expect(
      VoiceStop.selectLocale(['ja_JP', 'en_US', 'en_GB'], 'en', 'en-GB'),
      'en_GB',
    );
    expect(VoiceStop.selectLocale(['ja_JP', 'en_US'], 'en', 'fr_FR'), 'en_US');
    expect(VoiceStop.selectLocale(['ja-JP', 'en-US'], 'ja', 'ja_JP'), 'ja-JP');
    expect(VoiceStop.selectLocale(['ja_JP'], 'en', 'ja_JP'), isNull);
    expect(VoiceStop.selectLocale([], 'ja', null), isNull);
  });
}
