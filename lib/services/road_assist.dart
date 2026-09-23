import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'road_detector.dart';
import 'road_logic.dart';

/// 何を見張るか。
enum RoadMode {
  /// 前方（背面カメラを前へ）: 前方衝突・車間距離・前の車の発進
  drive,

  /// 歩行・後方（スマホを後ろ向きに）: 後ろから来る車
  walkBehind,

  /// 歩行・信号（スマホを前へ）: 信号の色を読む
  walkSignal,
}

/// カメラのフレームを受け取り、検出→判定→声で知らせる。
/// どの知らせも「補助」。鳴らなかったことを安全の根拠にしない。
class RoadAssist extends ChangeNotifier {
  RoadAssist({required this.mode, required this.say, this.onAlert});

  RoadMode mode;

  /// 読み上げる文（日本語・英語は呼び出し側が選ぶ）。
  final String Function(RoadEvent e) say;

  /// 音・振動など、声以外の知らせ（AlarmService.warn など）。
  final void Function(RoadEvent e)? onAlert;

  /// GPS の速度（km/h）。無ければ null（そのとき「止まっている」とは判断しない）。
  double? speedKmh;

  List<RoadObject> objects = const [];
  RoadObject? lead;
  double? ttc;
  SignalColor signal = SignalColor.unknown;
  RoadEvent? lastEvent;
  DateTime? lastEventAt;
  String? error;
  double fps = 0;

  final _det = RoadDetector();
  final _tts = FlutterTts();
  final _ttc = TtcTracker();
  final _fcw = FcwJudge();
  final _headway = HeadwayJudge();
  final _launch = LaunchJudge();
  final _approach = ApproachJudge();
  StreamSubscription<AccelerometerEvent>? _accel;
  double _gx = 0, _gy = 9.8;
  bool _busy = false, _disposed = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  SignalColor _spokenSignal = SignalColor.unknown;
  int _signalStreak = 0;
  SignalColor _signalCandidate = SignalColor.unknown;

  Future<void> start(String lang) async {
    try {
      await _det.load();
      await _tts.setLanguage(lang == 'ja' ? 'ja-JP' : 'en-US');
      await _tts.setSpeechRate(0.55);
      _accel = accelerometerEventStream().listen((e) {
        _gx = e.x;
        _gy = e.y;
      });
    } catch (e) {
      error = '$e';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 1 フレーム。推論中や直前 250ms 以内なら捨てる（4fps で十分、電池と熱を守る）。
  Future<void> feed(CameraImage img, int sensorOrientation) async {
    final now = DateTime.now();
    if (_busy || now.difference(_lastRun).inMilliseconds < 250) return;
    _busy = true;
    final gap = now.difference(_lastRun).inMilliseconds;
    _lastRun = now;
    try {
      final rot = uprightRotation(sensorOrientation, _gx, _gy);
      objects = await _det.detect(img, rot);
      if (gap < 2000) fps = fps * 0.8 + (1000 / gap) * 0.2;
      _judge(DateTime.now());
    } catch (e) {
      error = '$e';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _judge(DateTime now) {
    switch (mode) {
      case RoadMode.drive:
        final l = pickLead(objects);
        lead = l;
        if (l == null) {
          _ttc.reset();
          ttc = null;
        } else {
          ttc = _ttc.feed(l.width, now);
        }
        if (l != null && _fcw.feed(ttc: ttc, width: l.width, speedKmh: speedKmh, now: now)) {
          _emit(RoadEvent.forwardCollision, now);
        }
        if (_headway.feed(width: l?.width, speedKmh: speedKmh, now: now)) {
          _emit(RoadEvent.tooClose, now);
        }
        final stopped = speedKmh != null && speedKmh! < 3;
        if (_launch.feed(leadWidth: l?.width, stopped: stopped, now: now)) {
          _emit(RoadEvent.leadMoved, now);
        }
      case RoadMode.walkBehind:
        final v = pickLargestVehicle(objects);
        lead = v;
        if (v == null) {
          _ttc.reset();
          ttc = null;
        } else {
          ttc = _ttc.feed(v.width, now);
        }
        if (_approach.feed(ttc: ttc, width: v?.width, now: now)) {
          _emit(RoadEvent.carBehind, now);
        }
      case RoadMode.walkSignal:
        RoadObject? light;
        for (final o in objects) {
          if (o.kind == RoadKind.trafficLight && (light == null || o.area > light.area)) {
            light = o;
          }
        }
        lead = light;
        final c = light == null ? SignalColor.unknown : classifySignal(_det.crop(light));
        // 3 フレーム続けて同じ色のときだけ変わったことにする（見間違いで読み上げない）。
        _signalStreak = c == _signalCandidate ? _signalStreak + 1 : 1;
        _signalCandidate = c;
        if (_signalStreak >= 3) signal = c;
        if (signal != _spokenSignal && signal != SignalColor.unknown) {
          _spokenSignal = signal;
          _emit(signal == SignalColor.red ? RoadEvent.signalRed : RoadEvent.signalGo, now);
        }
    }
  }

  /// 外から（オービスなど）知らせる。
  void announce(RoadEvent e) => _emit(e, DateTime.now());

  void _emit(RoadEvent e, DateTime now) {
    lastEvent = e;
    lastEventAt = now;
    onAlert?.call(e);
    unawaited(_tts.speak(say(e)).catchError((_) => null));
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_accel?.cancel());
    unawaited(_det.close());
    unawaited(_tts.stop());
    super.dispose();
  }
}

enum RoadEvent {
  forwardCollision,
  tooClose,
  leadMoved,
  carBehind,
  signalRed,
  signalGo,
  speedCamera,
  overspeed,
}
