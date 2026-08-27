import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Posting a high-importance, vibrating notification does double duty on
/// Android: it buzzes the phone AND — because Wear OS mirrors phone
/// notifications by default — buzzes any paired watch too, with no separate
/// watch app required. This is intentionally the *only* way this app talks
/// to a watch; there's no companion Wear OS app.
class NotificationService {
  static const _channelId = 'sleep_alarm';
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

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
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> fireAlarm(String title, String body) async {
    if (!_ready) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      '居眠り・仮眠アラーム',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: true,
      vibrationPattern: null,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );
    await _plugin.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAlarm() async {
    if (!_ready) return;
    await _plugin.cancel(1001);
  }
}
