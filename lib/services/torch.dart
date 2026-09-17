import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// アラーム中、外側のライト（フラッシュLED）を点滅させる。
///
/// まぶた越しに届くのは色ではなく明るさの差なので、画面の白黒点滅
/// （AlarmFlashOverlay）と同じ理屈でライトも効く。閉じたまぶたの外側を
/// 直接光らせられるのは画面よりこっちのほうが早い。
///
/// Android にはカメラを開かずにライトを点ける口（setTorchMode）がある。
/// 背面カメラで見張っている間はそれが失敗する（自分でカメラを持って
/// いるため）ので、native 側で EyeService の撮影要求に TORCH を足して
/// 光らせる。その切り替えも含めて native（EyePlugin）がやる。ここは
/// 「点滅の律動」だけを担う。
class Torch {
  Torch._();

  static const _ch = MethodChannel('inemuri/torch');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Timer? _timer;
  static bool _lit = false;

  /// 400msごとに点と消を往復する。2.5Hz。画面の点滅（200ms×往復）より
  /// 少しゆっくり。ライトの点灯・消灯には数十msのかたさがあるので、
  /// 速すぎると「光りっぱなし」に見えてしまう。
  static Future<void> strobe() async {
    if (!isSupported) return;
    _timer ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
      _lit = !_lit;
      // 失敗しても止めない。ライトのない端末では毎回失敗するが、
      // 音・振動・画面は鳴り続けるべきなので。
      _ch.invokeMethod<void>(_lit ? 'on' : 'off').catchError((_) {});
    });
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_lit) {
      _lit = false;
      try {
        await _ch.invokeMethod<void>('off');
      } catch (_) {}
    }
  }
}
