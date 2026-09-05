import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Slack / Teams / メールの通知が来たら起こす。
///
/// ## なぜ通知を読む方式か
///
/// 各サービスの API を叩くなら OAuth と常駐サーバが要る。個人開発には重すぎるし、
/// 会社のワークスペースなら管理者の承認まで要る。**端末に届く通知を読む**なら
/// その全部が要らない。
///
/// ## 断っておくこと
///
/// 見ているのは**どのアプリから来たか**だけ。本文もタイトルも読んでいないし、
/// どこにも送らず保存もしない。通知アクセスは Android でもっとも強い権限の
/// ひとつなので、必要最小限しか触らないようにしてある。
///
/// この権限は**ユーザーが設定画面で自分で許可**しないと有効にならない。
/// アプリから勝手に有効にはできない（[openSettings] を開いてもらうしかない）。
class NudgeService extends ChangeNotifier {
  static const _method = MethodChannel('inemuri/eye');
  static const _events = EventChannel('inemuri/nudge_events');
  static const _kEnabled = 'nudge_enabled';

  StreamSubscription? _sub;

  /// 本人がこの機能を使うと決めたか。
  bool enabled = false;

  /// 通知アクセスが OS 側で許可されているか。
  bool granted = false;

  /// 直近に起こした相手（画面に出すだけ）。
  String? lastApp;

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// 起こす対象のアプリ名。設定画面に並べるためだけに使う。
  List<String> apps = const [];

  Future<void> load({required void Function(String app) onNudge}) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_kEnabled) ?? false;
    await refreshGranted();
    try {
      apps = (await _method.invokeMethod<List<Object?>>('nudgeApps') ?? [])
          .map((e) => e.toString())
          .toList();
    } catch (_) {}

    _sub = _events.receiveBroadcastStream().listen((e) {
      final app = e?.toString() ?? '';
      if (app.isEmpty) return;
      lastApp = app;
      notifyListeners();
      onNudge(app);
    }, onError: (Object err) => debugPrint('NudgeService stream error: $err'));

    await _push();
  }

  /// OS 側の許可状態を取り直す。設定画面から戻ってきたときに呼ぶ。
  Future<void> refreshGranted() async {
    if (!isSupported) return;
    try {
      granted = await _method.invokeMethod<bool>('nudgeIsGranted') ?? false;
    } catch (_) {
      granted = false;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool on) async {
    enabled = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, on);
    await _push();
    notifyListeners();
  }

  /// 通知アクセスの設定画面を開く。ここでしか許可できない。
  Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await _method.invokeMethod('nudgeOpenSettings');
    } catch (e) {
      debugPrint('NudgeService could not open settings: $e');
    }
  }

  /// native 側は「本人が使うと決めた かつ OS が許可している」ときだけ動かす。
  Future<void> _push() async {
    if (!isSupported) return;
    try {
      await _method.invokeMethod('nudgeSetEnabled', {'on': enabled && granted});
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
