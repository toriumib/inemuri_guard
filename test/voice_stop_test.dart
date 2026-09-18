import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/voice_stop.dart';

/// 声で止める語の照合。認識器は端末依存なので、照合だけを固定する。
void main() {
  test('「起きた」「止めて」系は止める', () {
    for (final s in ['起きた', 'おきた よ', 'もう 起きて', '止めて', 'ストップ', 'Stop it', '大丈夫です']) {
      expect(VoiceStop.matches(s), isTrue, reason: s);
    }
  });

  test('関係ない言葉では止めない', () {
    for (final s in ['', 'おはよう', '眠い', 'テレビ 消して']) {
      expect(VoiceStop.matches(s), isFalse, reason: s);
    }
  });
}
