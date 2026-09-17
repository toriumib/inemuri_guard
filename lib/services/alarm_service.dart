import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'notification_service.dart';
import 'torch.dart';

enum AlarmTone { chime, siren, bell }

extension AlarmToneX on AlarmTone {
  String get label => switch (this) {
    AlarmTone.chime => 'チャイム',
    AlarmTone.siren => 'サイレン',
    AlarmTone.bell => 'ベル連打',
  };

  String get asset => switch (this) {
    AlarmTone.chime => 'sfx/chime.wav',
    AlarmTone.siren => 'sfx/siren.wav',
    AlarmTone.bell => 'sfx/bell.wav',
  };

  Duration get gap => switch (this) {
    AlarmTone.chime => const Duration(milliseconds: 900),
    AlarmTone.siren => const Duration(milliseconds: 1150),
    AlarmTone.bell => const Duration(milliseconds: 650),
  };
}

/// Loops one of three synthesized alarm tones until [stop] is called, and
/// fans the same alarm out to: the ALARM audio stream (routes to Bluetooth
/// earbuds automatically, plays through Do Not Disturb/silent mode like a
/// real alarm clock), the phone's vibration motor, and a notification that
/// Wear OS mirrors to a paired watch (buzzing it too).
class AlarmService extends ChangeNotifier {
  final AudioPlayer _loopPlayer = AudioPlayer();
  final AudioPlayer _previewPlayer = AudioPlayer();
  final NotificationService notifications;
  Timer? _repeatTimer;

  AlarmService(this.notifications) {
    final alarmContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        },
      ),
    );
    _loopPlayer.setAudioContext(alarmContext);
  }

  AlarmTone tone = AlarmTone.chime;
  bool get isFiring => _repeatTimer != null;

  /// アラーム中に外側のライト（フラッシュLED）も点滅させるか。
  /// 画面の白黒点滅と同じ明暗で起こす仕組みの、端末の外側ぶん。
  /// 設定（StatsService.torchOnAlarm）と同期される。
  bool useTorch = true;

  void setTone(AlarmTone t) {
    tone = t;
    notifyListeners();
  }

  Future<void> preview() async {
    await _previewPlayer.stop();
    await _previewPlayer.play(AssetSource(tone.asset));
  }

  Future<void> start({String reason = '居眠りの兆候を検知しました'}) async {
    if (isFiring) return;
    // 通知を最初に投げる。音声の初期化は環境によって止まることがあり
    // （エミュレータやフォーカス争奪で await が返らないのを確認済み）、
    // 時計への転送だけは音の成否に引きずられないようにする。
    await notifications.fireAlarm('起きてください', reason);
    unawaited(_burst().catchError((_) {}));
    _repeatTimer = Timer.periodic(tone.gap, (_) => _burst());
    _startVibration();
    if (useTorch) unawaited(Torch.strobe());
    notifyListeners();
  }

  Future<void> stop() async {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    await _loopPlayer.stop();
    await Torch.stop();
    Vibration.cancel();
    notifications.cancelAlarm();
    notifyListeners();
  }

  Future<void> _burst() async {
    await _loopPlayer.stop();
    await _loopPlayer.play(AssetSource(tone.asset));
  }

  Future<void> _startVibration() async {
    final has = await Vibration.hasVibrator();
    if (has != true) return;
    // Long-short-short pattern, repeating from index 0 until cancelled.
    Vibration.vibrate(pattern: const [0, 500, 200, 250, 200, 250], repeat: 0);
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    Torch.stop();
    _loopPlayer.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }
}
