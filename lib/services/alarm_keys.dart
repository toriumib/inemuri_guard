import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// アラーム中に押された物理キー（音量・ホーム／履歴・メディアキー＝ハンドルの
/// 再生ボタンやイヤホンのボタン）を「止めたい」の合図として受け取る。
/// 別のアプリを前に出していても届く。運転中に触れるのはこれと声だけ。
///
/// 受け方は native（EyePlugin）。音量は VOLUME_CHANGED の放送、ホームと
/// 履歴は CLOSE_SYSTEM_DIALOGS の reason で見分ける。電源キーは受けない
/// （画面が勝手に消えたのと区別できず、車で裏向きに置いただけで止まる）。
class AlarmKeys {
  AlarmKeys._();

  static const _method = MethodChannel('inemuri/alarm_keys');
  static const _events = EventChannel('inemuri/alarm_key_events');
  static StreamSubscription? _sub;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 鳴り始めたら呼ぶ。[onPress] には "volume" / "home" / "media" が入る。
  static Future<void> watch(void Function(String why) onPress) async {
    if (!isSupported) return;
    _sub ??= _events.receiveBroadcastStream().listen((e) {
      onPress(e.toString());
    });
    try {
      await _method.invokeMethod<void>('watch');
    } catch (_) {}
  }

  /// 止まったら呼ぶ。鳴っていない間の音量操作で何も起きないように。
  static Future<void> unwatch() async {
    if (!isSupported) return;
    try {
      await _method.invokeMethod<void>('unwatch');
    } catch (_) {}
  }
}
