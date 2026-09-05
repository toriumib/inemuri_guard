import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 見張りを続けるための常駐サービス。
///
/// これが無いと、他のアプリに切り替えた瞬間や画面が消えた瞬間に Android が
/// カメラを取り上げ、検知が黙って止まる。机に置いて放置するという、この道具の
/// 一番の使い方が成立しない。
///
/// ⚠️ Android 14 以降、`camera` 型のサービスは**アプリが画面に出ている間しか
/// 開始できない**。必ずユーザーが「検知を開始」を押したその場で [start] を呼ぶこと。
/// あとからバックグラウンドで起こそうとしても失敗する。
///
/// 通知が常駐するのは避けられない（OS の仕様）。「周りにバレたくない」という
/// この道具の目的と衝突するので、**通知の文面は中身を明かさない**ようにしてある。
class WatchService {
  WatchService._();

  static const _channelId = 'watch_running';
  static bool _running = false;
  static bool get isRunning => _running;

  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: '見張り中',
        channelDescription: '検知を続けているあいだ表示されます。',
        // 常駐通知そのものが音や振動を出したら本末転倒なので黙らせる。
        // 起こすのは AlarmService の役目。
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 検知そのものは本体側の isolate で回っている。ここは
        // プロセスを生かしておくのが目的なので、間隔は長くてよい。
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// 通知の権限。断られてもサービス自体は動くが、通知が出ないぶん
  /// ユーザーからは「何が起きているか分からない」状態になる。
  static Future<void> requestPermissions() async {
    final p = await FlutterForegroundTask.checkNotificationPermission();
    if (p != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  static Future<void> start() async {
    if (_running) return;
    if (await FlutterForegroundTask.isRunningService) {
      _running = true;
      return;
    }
    try {
      await FlutterForegroundTask.startService(
        // 中身を明かさない文面にしてある。ロック画面に「居眠りを検知中」と
        // 出たら、それ自体が周りへの告知になってしまう。
        notificationTitle: '居眠りガード',
        notificationText: '動作中',
      );
      _running = true;
    } catch (e) {
      // 権限が無い、画面に出ていない、など。検知自体は前面にいる間は
      // 動くので、ここで落とさない。
      debugPrint('WatchService could not start: $e');
      _running = false;
    }
  }

  /// 常駐通知の文面を差し替える。
  /// 背面に回るとカメラは Android に取り上げられる（Flutter の camera プラグインは
  /// CameraX を Activity のライフサイクルに縛っているため、常駐サービスがあっても
  /// 防げない）。それを黙っているとユーザーは見張られていると誤解するので、
  /// 通知の文面だけは実態に合わせる。
  static Future<void> setText(String text) async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: '居眠りガード',
        notificationText: text,
      );
    } catch (e) {
      debugPrint('WatchService could not update text: $e');
    }
  }

  static Future<void> stop() async {
    if (!_running && !await FlutterForegroundTask.isRunningService) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('WatchService could not stop: $e');
    }
    _running = false;
  }
}
