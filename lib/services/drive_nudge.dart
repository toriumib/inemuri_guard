import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

/// 車に乗り続けていたら「休憩をおすすめします」を出す。
///
/// Android の身体活動認識（ActivityTransition）は「乗り物に乗っているか」
/// しか教えてくれない。車・バス・電車・タクシーを区別できないので、
/// 区別しない前提で勧め方を決めてある：
///   - 乗り続けて [sustain]（90秒）で初めて勧める（信号待ちや乗り降りで
///     繰り返し鳴らないように）
///   - 一度勧えたら [cooldown]（45分）は再勧誘しない
/// アプリを開いていればポップアップ、開いていなければ通知で届く。
///
/// これは眠気の兆候を検知するものではない。「乗り続けている」という
/// 状態への勧めだけ。運転の可否を判断する道具では絶対にない。
class DriveNudgeService extends ChangeNotifier {
  DriveNudgeService(this.notifications);

  static const _method = MethodChannel('inemuri/drive');
  static const _events = EventChannel('inemuri/drive_events');

  /// 乗り続けていたら勧めるまでの時間。
  static const sustain = Duration(seconds: 90);

  /// 一度勧えた後に、再勧誘を控える時間。
  static const cooldown = Duration(minutes: 45);

  final NotificationService notifications;

  /// OS への登録が済んでいて、乗り降りが届く状態か。
  bool active = false;

  /// いま乗り物に乗っていると OS が言っているか。
  bool get inVehicle => _vehicleSince != null;
  DateTime? _vehicleSince;

  /// 前回の勧め。表示と永続化の両方で使う。
  DateTime? lastNudge;

  /// 現在時刻の取り出し口。テストで90秒や45分の経過を作るためだけに
  /// 差し替える。本番では常に [DateTime.now]。
  /// （DrowsinessDetector の clock と同じ発想）
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// OS からの乗り降りの知らせを、テストから流し込む口。
  @visibleForTesting
  void debugEvent(bool vehicle) => _onEvent(vehicle);

  /// 30秒ごとの定期検査を、テストから叩く口。
  @visibleForTesting
  void tick() => _maybeNudge();

  /// アプリを開いているときの勧め方。HomeShell がポップアップを差し込む。
  void Function()? onSuggest;

  StreamSubscription? _sub;
  Timer? _check;

  /// 今回の起動で許可をもう聞いたか。
  /// 再開のたびに聞き直すと嫌われるので、一度しか聞かない。
  /// 設定を切り直したとき（stop を通ったとき）だけ聞き直す。
  bool _asked = false;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 見張りを始める。身体活動認識の許可を聞くのは、これを ON にするとき
  /// （初回起動時）の一度だけ。
  Future<void> start() async {
    if (!isSupported || active) return;
    final status = await Permission.activityRecognition.status;
    if (status.isPermanentlyDenied) return;
    var granted = status.isGranted;
    if (!granted) {
      if (_asked) return;
      _asked = true;
      granted =
          (await Permission.activityRecognition.request()).isGranted;
    }
    if (!granted) return;
    try {
      final ok = await _method.invokeMethod<bool>('start');
      if (ok != true) return;
    } catch (_) {
      return;
    }
    active = true;
    _sub ??= _events.receiveBroadcastStream().listen((e) {
      _onEvent(e == true);
    });
    _check ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _maybeNudge(),
    );
    notifyListeners();
  }

  Future<void> stop() async {
    if (!isSupported) return;
    _vehicleSince = null;
    // OFF にしたので、次に ON にしたら許可を聞き直してよい。
    _asked = false;
    if (active) {
      active = false;
      try {
        await _method.invokeMethod<void>('stop');
      } catch (_) {}
    }
    notifyListeners();
  }

  void _onEvent(bool vehicle) {
    if (vehicle) {
      _vehicleSince ??= clock();
    } else {
      _vehicleSince = null;
    }
    notifyListeners();
  }

  void _maybeNudge() {
    final since = _vehicleSince;
    if (since == null) return;
    final now = clock();
    if (now.difference(since) < sustain) return;
    final last = lastNudge;
    if (last != null && now.difference(last) < cooldown) return;

    lastNudge = now;
    // 数え直し。勧めた直後の状態のままだと、45分後に「乗り続けている」
    // だけでまたすぐ鳴ってしまう。
    _vehicleSince = null;

    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (resumed && onSuggest != null) {
      onSuggest!();
    } else {
      notifications.fireBreakSuggestion();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _check?.cancel();
    super.dispose();
  }
}
