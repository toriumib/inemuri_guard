import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_scheduler.dart';

/// Posting a high-importance, vibrating notification does double duty on
/// Android: it buzzes the phone AND — because Wear OS mirrors phone
/// notifications by default — buzzes any paired watch too, with no separate
/// watch app required. This is intentionally the *only* way this app talks
/// to a watch; there's no companion Wear OS app.
///
/// [bridgeToWatch] controls that mirroring. Off = the notification is posted
/// with FLAG_LOCAL_ONLY, which tells Android not to bridge it to a paired
/// watch (the phone still vibrates normally). Set from StatsService on
/// startup and whenever the user flips the 設定 toggle.
class NotificationService implements NotificationScheduler {
  static const _channelId = NotificationChannels.alarm;
  static const _flagLocalOnly = 0x100; // Notification.FLAG_LOCAL_ONLY
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool bridgeToWatch = true;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      '居眠り・仮眠アラーム',
      description: '目を閉じた/寝息を検知した、または仮眠タイマー終了時に鳴らす通知（時計にも振動が届きます）',
      importance: Importance.max,
      playSound:
          false, // the app plays its own alarm tone; this channel is for vibration/bridging only
      enableVibration: true,
      vibrationPattern: null,
    );
    // ポモドーロは「区間が終わった」の合図。音と振動はあるが、居眠りの
    // アラームのように全画面で叩き起こすものではない。
    const pomodoro = AndroidNotificationChannel(
      NotificationChannels.pomodoro,
      'ポモドーロ',
      description: '作業・休憩の区間が終わったときの合図',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    // 水分補給はさらに控えめ。ヘッドアップも出さない。
    const hydration = AndroidNotificationChannel(
      NotificationChannels.hydration,
      '水分補給',
      description: '決めた間隔で水を一口すすめる通知',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );
    // 車で眠気を検知したときの休憩の案内。アラームが止まったあとも
    // 残るので、停めてから見て、近くの駐車場を探す入口になる。
    const restAdvice = AndroidNotificationChannel(
      NotificationChannels.restAdvice,
      '休憩の案内',
      description: '車で眠気を検知したときに、安全な場所で休憩するようすすめる通知',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(channel);
    await android?.createNotificationChannel(pomodoro);
    await android?.createNotificationChannel(hydration);
    await android?.createNotificationChannel(restAdvice);
    await android?.requestNotificationsPermission();
    // zonedSchedule は TZDateTime しか受け付けない。絶対時刻を UTC で渡す
    // ので、端末のゾーン名を調べる必要はない。
    tzdata.initializeTimeZones();
    _ready = true;
  }

  /// 予約通知。inexact なので数分遅れることがある（Doze）。
  /// 正確なアラームには SCHEDULE_EXACT_ALARM が要るが、Play のポリシー上
  /// 慎重に扱われる権限なので使わない。水分補給や作業の区切りに数分の
  /// 遅れは困らない。
  @override
  Future<void> scheduleAt({
    required int id,
    required String channel,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_ready) return;
    final details = AndroidNotificationDetails(
      channel,
      channel == NotificationChannels.pomodoro ? 'ポモドーロ' : '水分補給',
      importance: channel == NotificationChannels.pomodoro
          ? Importance.high
          : Importance.defaultImportance,
      priority: channel == NotificationChannels.pomodoro
          ? Priority.high
          : Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
      additionalFlags: bridgeToWatch
          ? null
          : Int32List.fromList([_flagLocalOnly]),
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        at.toUtc().millisecondsSinceEpoch,
      ),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // iOS 向けの必須引数。Android しか出さないが、無いとコンパイルが通らない。
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelRange(int from, int toExclusive) async {
    if (!_ready) return;
    for (var id = from; id < toExclusive; id++) {
      await _plugin.cancel(id);
    }
  }

  Future<void> fireAlarm(String title, String body) async {
    if (!_ready) {
      debugPrint('fireAlarm: skipped, not ready');
      return;
    }
    debugPrint('fireAlarm: posting (bridgeToWatch=$bridgeToWatch)');
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      '居眠り・仮眠アラーム',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: true,
      // Three 700ms bursts with short gaps. A short single buzz is easy to
      // sleep through on a wrist; a repeating pattern reads as "wake up".
      vibrationPattern: Int64List.fromList([0, 700, 350, 700, 350, 700]),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      additionalFlags: bridgeToWatch
          ? null
          : Int32List.fromList([_flagLocalOnly]),
    );
    await _plugin.show(
      NotificationIds.alarm,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    debugPrint('fireAlarm: posted');
  }

  Future<void> cancelAlarm() async {
    if (!_ready) return;
    await _plugin.cancel(NotificationIds.alarm);
  }

  /// 車で眠気を検知したときの休憩の案内。マップなど別のアプリを前に
  /// 出している間の届け口。アラーム通知（起こす側）は止めると消えるが、
  /// これは本人が消すまで残す——停めてから読むものだから。
  Future<void> fireRestAdvice() async {
    if (!_ready) return;
    const details = AndroidNotificationDetails(
      NotificationChannels.restAdvice,
      '休憩の案内',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.recommendation,
      styleInformation: BigTextStyleInformation(
        '眠気を検知しました。次の SA・PA、駐車場、路肩など安全な場所に停めて休んでください。'
        'タップで開くと、近くの駐車場を地図で探せます。',
      ),
    );
    await _plugin.show(
      NotificationIds.restAdvice,
      '休憩しましょう',
      '眠気を検知しました。SA・PA、駐車場、路肩など安全な場所で休んでください。',
      const NotificationDetails(android: details),
    );
  }
}
