import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「車に乗ったら始める」の Dart 側。
///
/// 乗った・降りたの検知そのものは native（CarTriggerReceiver）。
/// アプリが死んでいるときは native が通知（ロック中は全画面）を出して
/// アプリを開かせ、開いた先で自動開始が走る。アプリが生きているときは
/// ここに "boarded" / "left" が届くので、その場で見張りを始める・止める。
///
/// 保存の鍵は native も読む（FlutterSharedPreferences の "flutter." 付き）。
class CarTrigger extends ChangeNotifier {
  static const _method = MethodChannel('inemuri/car');
  static const _events = EventChannel('inemuri/car_events');

  /// native の CarTriggerReceiver と同じ鍵。
  static const kBtAddress = 'car_bt_address';
  static const kBtName = 'car_bt_name';
  static const kStartOnDrive = 'start_on_drive';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? btAddress;
  String? btName;
  bool startOnDrive = false;

  /// 「乗った」が届いたときに呼ばれる。HomeShell が見張りの開始を差し込む。
  void Function(String why)? onBoarded;

  /// 「降りた」。見張りを止める。
  void Function(String why)? onLeft;

  StreamSubscription? _sub;

  Future<void> load() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    btAddress = prefs.getString(kBtAddress);
    btName = prefs.getString(kBtName);
    startOnDrive = prefs.getBool(kStartOnDrive) ?? false;
    _sub ??= _events.receiveBroadcastStream().listen((e) {
      final s = e.toString();
      final why = s.contains(':') ? s.split(':').last : '';
      if (s.startsWith('boarded')) onBoarded?.call(why);
      if (s.startsWith('left')) onLeft?.call(why);
    }, onError: (Object _) {});
    if (startOnDrive) unawaited(_method.invokeMethod('startDrive'));
    notifyListeners();
  }

  /// ペアリング済みの機器。12 以降は BLUETOOTH_CONNECT の許可を先に取る。
  Future<List<({String name, String address})>> bondedDevices() async {
    if (!isSupported) return const [];
    final st = await Permission.bluetoothConnect.request();
    if (!st.isGranted && !st.isLimited) return const [];
    try {
      final raw = await _method.invokeMethod<List<dynamic>>('bondedDevices');
      return (raw ?? const [])
          .map((d) => (d as Map))
          .map((d) => (name: '${d['name']}', address: '${d['address']}'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setCar(String? address, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (address == null) {
      await prefs.remove(kBtAddress);
      await prefs.remove(kBtName);
    } else {
      await prefs.setString(kBtAddress, address);
      await prefs.setString(kBtName, name ?? address);
    }
    btAddress = address;
    btName = address == null ? null : (name ?? address);
    notifyListeners();
  }

  /// 運転を体で検知して始める（試験的）。ON にしたときに許可を聞く。
  Future<bool> setStartOnDrive(bool on) async {
    if (!isSupported) return false;
    if (on) {
      final st = await Permission.activityRecognition.request();
      if (!st.isGranted) return false;
      final ok = await _method.invokeMethod<bool>('startDrive') ?? false;
      if (!ok) return false;
    } else {
      try {
        await _method.invokeMethod('stopDrive');
      } catch (_) {}
    }
    startOnDrive = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStartOnDrive, on);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
