import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        debugPrint,
        defaultTargetPlatform,
        TargetPlatform,
        visibleForTesting,
        WriteBuffer;
import 'package:flutter/widgets.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'native_eye.dart';
import 'screen_wake.dart';

enum DetectorState { idle, starting, watching, denied, alarming }

/// Real eyelid-closure detection: reads ML Kit's leftEyeOpenProbability /
/// rightEyeOpenProbability per frame (this needs enableClassification).
///
/// Two independent triggers raise the alarm, mirroring how real drowsiness
/// systems work (cheap anti-sleep glasses use a single continuous-closure
/// timer; automotive-grade systems add PERCLOS):
///   1. Continuous closure: eyes stayed below [openThreshold] for
///      [closedThreshold] in one unbroken stretch — a real "nodding off".
///   2. PERCLOS (PERcentage of eyelid CLOSure): the fraction of the last
///      60s where eyes were mostly closed. This catches repeated heavy,
///      slow blinks/"droops" that never individually reach the continuous
///      threshold but are the classic early sign of drowsiness in sleep
///      research (Oxford Sleep Advances 2023; Sensors 22(14):5380, 2022).
class DrowsinessDetector extends ChangeNotifier {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      // 眼鏡・マスクで顔の一部が隠れても拾えるよう accurate にした。
      // fast の2〜3倍遅いが、瞼の開閉は秒単位の現象なので 6fps あれば足りる。
      // 解析時間がフレーム間隔（_minFrameGap）を超えるなら間隔のほうを広げる。
      performanceMode: FaceDetectorMode.accurate,
      // 一度捉えた顔を追い続ける。マスクで見失いやすい顔を毎フレーム探し直す
      // より、追跡のほうが粘る。
      enableTracking: true,
    ),
  );

  CameraController? _controller;
  bool _busy = false;
  DateTime? _eyesClosedSince;
  DateTime? _suppressUntil;

  DetectorState state = DetectorState.idle;
  double eyeOpenness = 1.0; // 0 = fully closed, 1 = fully open (smoothed)
  Duration closedFor = Duration.zero;
  Duration closedThreshold = const Duration(seconds: 5);
  double openThreshold = 0.35;
  bool alarmFiring = false;
  bool noFaceSeen = false;

  /// 背面に回っていてカメラが取り上げられている状態。
  /// 「検知中」と表示したまま実際は何も見ていない、を避けるために持つ。
  bool cameraPausedInBackground = false;

  /// 背面カメラで見張るか。車のスタンドに載せて運転席へ向けるときに使う。
  /// 見張っている最中に変えても、次に開き直したときから効く。
  bool useBackCamera = false;

  /// 背面での見張りが続けられなくなった理由。表示して隠さないために持つ。
  /// カメラを開けない端末があっても「検知中」と嘘をつかない。
  String? backgroundFailure;

  final List<double> history = [];
  static const historyMax = 90;

  // Small rolling window so a single noisy frame (blink, motion blur, bad
  // lighting) can't spike eyeOpenness open/closed on its own — the alarm
  // reacts to a sustained trend, not one bad reading.
  final List<double> _smoothingWindow = [];
  static const _smoothingSize = 4;

  // PERCLOS window: percentage of the last 60s spent with eyes mostly
  // closed. See class doc.
  final List<_TimedSample> _perclosWindow = [];
  static const _perclosWindowSeconds = 60;
  static const _perclosCloseThreshold = 0.2; // "mostly closed" cutoff
  static const _perclosAlarmRatio = 0.15; // validated in PERCLOS literature
  static const _perclosMinSamples = 30;

  /// PERCLOS が鳴らしてよくなるまでに必要な、**実際に経過した時間**。
  ///
  /// ここを「集まったサンプル数」だけで見ていたのが、しきい値を10秒に
  /// してもすぐ鳴っていた原因だった。解析は約6回/秒なので 30 サンプルは
  /// **5秒ぶん**にしかならず、起動5秒後に1秒目を閉じただけで
  /// 6/30 = 0.2 ≥ 0.15 となって鳴っていた。
  /// PERCLOS は「直近1分のうち何割を閉じていたか」であって、
  /// 「直近5秒のうち何割か」ではない。1分ぶん貯まるまでは判断しない。
  static const _perclosWarmUp = Duration(seconds: _perclosWindowSeconds);
  double perclos = 0;

  /// 現在時刻の取り出し口。テストで1分の経過を作るためだけに差し替える。
  /// 本番では常に [DateTime.now]。
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  // Eyelid closure plays out over seconds, so there is nothing to gain from
  // running ML Kit at the camera's full frame rate — and plenty to lose,
  // since this app is meant to sit on a desk running all afternoon.
  // accurate モードの解析は SHARP A105SH で 150〜255ms かかった（実測）。
  // 160ms だと間に合わず _busy でフレームを捨てるだけなので 250ms（4fps）。
  // PERCLOS には十分で、発熱も減る。native 側（EyeService.kt）と同じ値。
  static const _minFrameGap = Duration(milliseconds: 250);
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _wakeKey = 'detect';

  // The UI does not need a rebuild per analysed frame either. Numbers refresh
  // a few times a second; anything that changes *state* (alarm on/off, face
  // lost/found) still notifies immediately via [_notify].
  static const _minNotifyGap = Duration(milliseconds: 200);
  DateTime _lastNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _notify({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotifyAt) < _minNotifyGap) return;
    _lastNotifyAt = now;
    notifyListeners();
  }

  Future<void> start() async {
    state = DetectorState.starting;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      final wanted = useBackCamera
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      _controller = controller;
      _eyesClosedSince = null;
      alarmFiring = false;
      history.clear();
      _smoothingWindow.clear();
      _perclosWindow.clear();
      perclos = 0;
      await controller.startImageStream(_onFrame);
      // Without this the screen sleeps a minute after the last touch, Android
      // tears the camera down, and detection dies silently — which breaks the
      // one thing this app is for: sitting on the desk watching you.
      await ScreenWake.acquire(_wakeKey);
      // 常駐サービスはここで起こす。ユーザーが開始を押した直後＝アプリが
      // 前面にいるこの瞬間しか、Android 14 以降は camera 型を開始できない。
      // native の見張りサービスも**ここで**起こす。カメラはまだ Flutter 側が
      // 持っているので触らせない（取得は背面に入る直前の acquire で行う）。
      // Android 14 は camera 型の前景サービスを背面から開始できないため、
      // 前面にいるこの瞬間に前景化しておく必要がある。
      backgroundFailure = null;
      await NativeEye.start(
        holder: 'eye',
        notificationText: '動作中',
        useBackCamera: useBackCamera,
        onFailed: (message) {
          // 背面での見張りが死んだ。黙って「検知中」を出し続けるより、
          // 見張れていないと言うほうがましなので、そのまま画面に出す。
          backgroundFailure = message;
          cameraPausedInBackground = true;
          notifyListeners();
        },
        onReading: (face, l, r) {
          if (!face) {
            noteFaceLost();
            _notify();
            return;
          }
          noteFaceSeen();
          if (l == null || r == null) return;
          ingestEyes(l, r);
        },
      );
      state = DetectorState.watching;
    } catch (_) {
      state = DetectorState.denied;
      await ScreenWake.release(_wakeKey);
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await NativeEye.stop('eye');
    await ScreenWake.release(_wakeKey);
    alarmFiring = false;
    noFaceSeen = false;
    _noFaceSince = null;
    backgroundFailure = null;
    _handedOverToNative = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    state = DetectorState.idle;
    eyeOpenness = 1.0;
    closedFor = Duration.zero;
    history.clear();
    _smoothingWindow.clear();
    _perclosWindow.clear();
    perclos = 0;
    notifyListeners();
  }

  CameraController? get controller => _controller;

  void setThresholdSeconds(int seconds) {
    closedThreshold = Duration(seconds: seconds);
  }

  /// 前面／背面の切り替え。見張っている最中なら、その場で開き直す。
  Future<void> setUseBackCamera(bool value) async {
    if (useBackCamera == value) return;
    useBackCamera = value;
    if (state == DetectorState.watching) {
      await stop();
      await start();
    } else {
      notifyListeners();
    }
  }

  /// Android reclaims the camera whenever the app leaves the foreground, and
  /// the old controller is dead on return — the preview would come back black
  /// and detection would never resume. Tear it down on the way out and build
  /// a fresh one on the way back in.
  bool _resumeWhenForegrounded = false;

  /// native 側へ引き継ぎ済みか。
  ///
  /// Flutter は背面へ回るとき hidden と paused を続けて送るので、
  /// [handleAppPaused] は一度の切り替えで二度呼ばれる。素直に二度
  /// 引き継ぐと native 側が開いている最中のカメラをもう一度開き、
  /// 自分とカメラを奪い合って落ちる（実機で確認）。
  bool _handedOverToNative = false;

  Future<void> handleAppPaused() async {
    if (state != DetectorState.watching) return;
    // 常駐サービスが動いていれば、背面に回っても Android はカメラを
    // 取り上げない。ここで止めてしまうと「他のアプリを開いた瞬間に
    // 見張りが終わる」という、この道具の一番の欠陥がそのまま残る。
    // 背面では Flutter 側のカメラが Android に取り上げられる。
    // そこで native の Camera2（Service が持つ）へ引き継ぐ。
    if (NativeEye.isRunning) {
      if (_handedOverToNative) return;
      _handedOverToNative = true;
      await _handOverToNative();
      return;
    }
    // native 経路が使えない端末（権限を断られた等）だけ、従来どおり畳んで
    // 復帰時に張り直す。壊れたカメラを抱えたままにするよりよい。
    // サービスを起こせなかった端末（権限を断られた等）だけ、従来どおり
    // 畳んで復帰時に張り直す。壊れたカメラを抱えたままにするよりよい。
    _resumeWhenForegrounded = true;
    await stop();
  }

  Future<void> handleAppResumed() async {
    if (NativeEye.isRunning && state == DetectorState.watching) {
      if (!_handedOverToNative) return;
      _handedOverToNative = false;
      await _takeBackFromNative();
      return;
    }
    if (cameraPausedInBackground) {
      // CameraX が自分で繋ぎ直すので、こちらは表示を戻すだけでよい。
      cameraPausedInBackground = false;
      notifyListeners();
    }
    if (!_resumeWhenForegrounded) return;
    _resumeWhenForegrounded = false;
    await start();
  }

  /// 背面に回るときの引き継ぎ。
  ///
  /// Flutter 側のカメラを畳んでから native を起こす。カメラは同時に
  /// 一つしか開けないので、順番を逆にすると native 側が開けずに失敗する。
  Future<void> _handOverToNative() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await controller.dispose();
      } catch (_) {}
    }
    // Flutter 側が手放したあとで取りにいく。カメラは同時に一つしか
    // 開けないので、順番を逆にすると native 側が開けずに失敗する。
    await NativeEye.acquire(useBackCamera: useBackCamera);
    notifyListeners();
  }

  /// 前面に戻ったら native を止め、Flutter 側のカメラを張り直す。
  /// プレビューを出せるのはこちらだけなので、見えている間はこちらに戻す。
  Future<void> _takeBackFromNative() async {
    // native にカメラを手放させてから、Flutter 側で開き直す。
    // サービスは止めない（次に背面へ回るときのために前景のまま置く）。
    await NativeEye.release();
    if (state == DetectorState.watching) {
      await _reopenFlutterCamera();
    }
  }

  /// プレビュー用に Flutter 側のカメラを開き直す。
  /// [start] を呼ぶとサービスの起動などをやり直してしまうので、
  /// カメラだけを張り直す。
  Future<void> _reopenFlutterCamera() async {
    try {
      final cameras = await availableCameras();
      final wanted = useBackCamera
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      _controller = controller;
      await controller.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('カメラを開き直せなかった: $e');
    }
    notifyListeners();
  }

  /// Silences the current alarm and ignores closed-eye time for 3 minutes.
  void snooze() {
    alarmFiring = false;
    _eyesClosedSince = null;
    closedFor = Duration.zero;
    _perclosWindow.clear();
    perclos = 0;
    _suppressUntil = clock().add(const Duration(minutes: 3));
    notifyListeners();
  }

  /// 目の開き具合ひとつぶんの判定。
  ///
  /// **Flutter 側のカメラと native の Camera2 の両方がここを通る。**
  /// しきい値も PERCLOS もここにしか無い。二か所に同じ判断を書くと、
  /// 必ず片方だけ直して食い違うため。
  /// カメラ無しで判定だけを試すための入口。実機のカメラ2経路と
  /// まったく同じ [_ingest] を通る（別の道を用意すると、直したつもりの
  /// 判定がテストでしか通らなくなる）。
  @visibleForTesting
  void ingestForTest(double raw) => _ingest(raw);

  /// 左右の目の開き具合を1つにまとめる。**平均ではなく、開いているほう。**
  ///
  /// 眼鏡のレンズに光が反射すると、片目だけが「閉じている」と読まれる。
  /// 平均だと、そのたびに閉眼時間が積み上がって誤って鳴る。
  /// 両目とも閉じたときだけ「閉」とすれば、片目の読み違いに強くなる。
  /// ウィンクや片目を擦る動作で鳴らなくなるが、それは眠りではないので失わない。
  ///
  /// ⚠️ 既知の弱点: フレームで片目が半分隠れて 0.5 前後を返し続けると、
  /// もう片方が本当に閉じていても「開」に寄って見逃す。平均なら拾えた場面。
  /// 切り替えをここ1か所に閉じ込めてあるのは、実機で測って悪ければ
  /// 平均や「差が大きいときだけ平均」に戻せるようにするため。
  @visibleForTesting
  static double combineEyes(double left, double right) =>
      left > right ? left : right;

  /// カメラ2経路（Flutter 側と native 側）の**両方**がここを通る。
  /// 片方だけ直して食い違う、を防ぐための一本化。
  void ingestEyes(double left, double right) =>
      _ingest(combineEyes(left, right));

  /// 顔を見失った。
  ///
  /// 見失っている間は「閉じている」とも「開いている」とも言えない。
  /// ここで閉眼タイマーをリセットしないと、目を閉じたまま顔が外れて戻って
  /// きたときに、外れていた時間まで閉眼として数えてしまう（Web 版は
  /// 最初からリセットしていた。Android だけ抜けていた）。
  /// PERCLOS は実際のサンプルしか積まないので触らない。
  /// 鳴っているアラームは止めない——顔を隠せば止まる、では困る。
  void noteFaceLost() {
    noFaceSeen = true;
    _noFaceSince ??= clock();
    if (!alarmFiring) {
      _eyesClosedSince = null;
      closedFor = Duration.zero;
    }
  }

  DateTime? _noFaceSince;

  /// 顔が戻った。[noteFaceLost] の対。両方の経路がここを通る。
  void noteFaceSeen() {
    noFaceSeen = false;
    _noFaceSince = null;
  }

  /// 顔を3秒以上見失っている。よくある原因（眼鏡の反射・マスク・暗さ）を
  /// 画面で伝えるための目安。一瞬の見失いでいちいち出すと煩い。
  bool get faceLostLong =>
      _noFaceSince != null &&
      clock().difference(_noFaceSince!) >= const Duration(seconds: 3);

  void _ingest(double raw) {
    _smoothingWindow.add(raw);
    if (_smoothingWindow.length > _smoothingSize) {
      _smoothingWindow.removeAt(0);
    }
    eyeOpenness =
        _smoothingWindow.reduce((a, b) => a + b) / _smoothingWindow.length;
    history.add(eyeOpenness);
    if (history.length > historyMax) history.removeAt(0);

    final now = clock();
    final suppressed = _suppressUntil != null && now.isBefore(_suppressUntil!);
    final wasAlarming = alarmFiring;

    if (suppressed) {
      _eyesClosedSince = null;
      closedFor = Duration.zero;
    } else if (eyeOpenness < openThreshold) {
      _eyesClosedSince ??= now;
      closedFor = now.difference(_eyesClosedSince!);
    } else {
      _eyesClosedSince = null;
      closedFor = Duration.zero;
      if (alarmFiring) alarmFiring = false;
    }

    if (suppressed) {
      _perclosWindow.clear();
      perclos = 0;
    } else {
      _perclosWindow.add(_TimedSample(now, eyeOpenness));
      final cutoff = now.subtract(
        const Duration(seconds: _perclosWindowSeconds),
      );
      _perclosWindow.removeWhere((s) => s.time.isBefore(cutoff));
      if (_perclosWindow.length >= _perclosMinSamples) {
        final closedCount = _perclosWindow
            .where((s) => s.openness < _perclosCloseThreshold)
            .length;
        perclos = closedCount / _perclosWindow.length;
      } else {
        perclos = 0;
      }
    }

    // 1分ぶん貯まったか。貯まるまでの割合はまだ意味を持たない。
    final span = _perclosWindow.isEmpty
        ? Duration.zero
        : now.difference(_perclosWindow.first.time);
    final perclosReady =
        span >= _perclosWarmUp && _perclosWindow.length >= _perclosMinSamples;

    if (!alarmFiring) {
      final byClosure = closedFor >= closedThreshold;
      final byPerclos =
          !suppressed && perclosReady && perclos >= _perclosAlarmRatio;
      if (byClosure || byPerclos) {
        alarmFiring = true;
        if (byPerclos) {
          // 一度 PERCLOS で鳴らしたら、その1分ぶんは使い切ったものとして
          // 捨てる。残したままだと、目を開けて止まった直後にまだ高いままの
          // 割合でもう一度鳴り、鳴りっぱなしに見える。
          _perclosWindow.clear();
          perclos = 0;
        }
      }
    }
    // 背面では UI が居ないので、鳴らす判断の変化だけは必ず通す。
    _notify(force: alarmFiring != wasAlarming);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _controller == null) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _minFrameGap) return;
    _lastFrameAt = now;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      final wasAlarming = alarmFiring;
      final hadFace = !noFaceSeen;
      if (faces.isEmpty) {
        noteFaceLost();
      } else {
        noteFaceSeen();
        final face = faces.first;
        final l = face.leftEyeOpenProbability;
        final r = face.rightEyeOpenProbability;
        if (l != null && r != null) {
          ingestEyes(l, r);
        }
      }
      // A change in alarm or face state must reach the UI now; the rest is
      // just numbers ticking and can wait for the next throttle window.
      _notify(force: alarmFiring != wasAlarming || hadFace == noFaceSeen);
    } catch (_) {
      // Drop malformed frames silently; next frame will retry.
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
    // Multi-plane (e.g. YUV420) — concatenate as ML Kit expects for NV21-like input.
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _faceDetector.close();
    await _controller?.dispose();
    super.dispose();
  }
}

class _TimedSample {
  final DateTime time;
  final double openness;
  _TimedSample(this.time, this.openness);
}
