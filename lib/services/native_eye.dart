import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 背面でも瞼を見続けるための native 実装への窓口。
///
/// Flutter の camera プラグインは CameraX を Activity のライフサイクルに
/// 縛るため、画面を離れるとカメラを手放す。native 側（[EyeService]）は
/// Camera2 を Service が持つので、その縛りから外れる。
///
/// ここが返すのは「顔が居るか」と「左右それぞれの目の開き具合」だけ。
/// しきい値も PERCLOS も Dart 側（DrowsinessDetector）に置いたままにしてある。
/// 同じ判断を二か所に書くと、必ず片方だけ直して食い違うため。
class NativeEye {
  NativeEye._();

  static const _method = MethodChannel('inemuri/eye');
  static const _events = EventChannel('inemuri/eye_events');

  static StreamSubscription? _sub;
  static bool _running = false;
  static bool get isRunning => _running;

  /// サービスを必要としている機能。瞼(カメラ)と寝息(マイク)は別々に
  /// 開始・停止できるので、片方を止めたときにもう片方の背面動作まで
  /// 巻き添えで止まらないよう、保持者を数える。
  static final Set<String> _holders = {};

  /// native 経路が使えるか。Android 以外では常に false。
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// カメラを受け取る（背面に入る直前に呼ぶ）。
  /// サービス自体は [start] で前面にいるうちに前景化してある。
  /// Android 14 は camera 型の前景サービスを背面から**開始**できないので、
  /// 開始と取得を分けてある。ここを一つにすると SecurityException で落ちる。
  static Future<void> acquire() async {
    if (!isSupported || !_running) return;
    try {
      await _method.invokeMethod('acquire');
    } catch (e) {
      debugPrint('NativeEye could not acquire: $e');
    }
  }

  /// 前面に戻るのでカメラを手放す。Flutter 側がプレビューに使う。
  static Future<void> release() async {
    if (!isSupported || !_running) return;
    try {
      await _method.invokeMethod('release');
    } catch (e) {
      debugPrint('NativeEye could not release: $e');
    }
  }

  /// 目の開き具合が届くたびに呼ばれる。
  /// [face] が false のときは顔が映っていない（離席と睡眠は区別できないので、
  /// 呼び出し側で鳴らさない判断をすること）。
  /// [holder] はこのサービスを必要としている機能の名前（'eye' / 'breath'）。
  /// [onReading] は瞼の値が要る側だけ渡す。
  static Future<void> start({
    required String holder,
    String notificationText = '動作中',
    void Function(bool face, double? left, double? right)? onReading,
  }) async {
    if (!isSupported) return;
    _holders.add(holder);
    if (_running) {
      if (onReading != null) _attach(onReading);
      return;
    }
    try {
      if (onReading != null) _attach(onReading);
      await _method.invokeMethod('start', {'text': notificationText});
      _running = true;
    } catch (e) {
      // 権限が無い・前面にいない等。前面にいる間は Flutter 側のカメラで
      // 動くので、ここで落とさない。
      debugPrint('NativeEye could not start: $e');
      await stop(holder);
    }
  }

  static void _attach(
    void Function(bool face, double? left, double? right) onReading,
  ) {
    _sub?.cancel();
    _sub = _events.receiveBroadcastStream().listen((e) {
      if (e is! Map) return;
      onReading(
        e['face'] == true,
        (e['left'] as num?)?.toDouble(),
        (e['right'] as num?)?.toDouble(),
      );
    }, onError: (Object err) => debugPrint('NativeEye stream error: $err'));
  }

  static Future<void> stop(String holder) async {
    _holders.remove(holder);
    // まだ誰かが使っているなら、サービスは落とさない。
    if (_holders.isNotEmpty) return;
    await _sub?.cancel();
    _sub = null;
    if (!isSupported) {
      _running = false;
      return;
    }
    try {
      await _method.invokeMethod('stop');
    } catch (e) {
      debugPrint('NativeEye could not stop: $e');
    }
    _running = false;
  }
}
