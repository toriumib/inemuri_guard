import '../l10n/app_language.dart';
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
import 'package:flutter/widgets.dart'
    show AppLifecycleState, Size, WidgetsBinding;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'native_eye.dart';
import 'screen_wake.dart';
import 'face_target.dart';

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
  bool _eyeAlarm = false;
  bool _postureAlarm = false;
  bool get eyeAlarm => _eyeAlarm;
  bool get postureAlarm => _postureAlarm;
  bool get alarmFiring => _eyeAlarm || _postureAlarm;
  final FaceTarget faceTarget = FaceTarget();
  Timer? _healthTimer;
  DateTime? _lastInputAt;
  DateTime? _lastEyesAt;
  DateTime? _lastPoseAt;
  bool inputStalled = false;
  bool get eyesAvailable =>
      _seenOpenAt != null &&
      !eyesUnreadable &&
      _lastEyesAt != null &&
      clock().difference(_lastEyesAt!) <= const Duration(seconds: 2);
  bool get poseAvailable =>
      _lastPoseAt != null &&
      clock().difference(_lastPoseAt!) <= const Duration(seconds: 2);
  String get monitoringLabel => monitoringLabelFor(AppLanguage.current);

  String monitoringLabelFor(AppLocalizations l) {
    if (state == DetectorState.denied) return l.cameraUnavailable;
    if (state == DetectorState.starting) return l.cameraStarting;
    if (state != DetectorState.watching) return l.monitoringStopped;
    if (inputStalled || cameraPausedInBackground) return l.cameraInputStopped;
    if (noFaceSeen) return l.targetFaceMissing;
    if (!eyesAvailable) return poseAvailable ? l.poseOnly : l.checkingFaceEyes;
    return poseAvailable ? l.watchingEyesPose : l.watchingEyes;
  }

  void noteInput() {
    final now = clock();
    if (_lastInputAt != null &&
        now.difference(_lastInputAt!) > const Duration(seconds: 2)) {
      noteFaceLost();
    }
    _lastInputAt = now;
    inputStalled = false;
    cameraPausedInBackground = false;
    backgroundFailure = null;
  }

  @visibleForTesting
  void checkInputHealth() {
    if (state != DetectorState.watching || _lastInputAt == null) return;
    if (clock().difference(_lastInputAt!) > const Duration(seconds: 3) &&
        !inputStalled) {
      inputStalled = true;
      noteFaceLost();
      _notify(force: true);
    }
  }

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

  // ── 頭の姿勢（度）。ML Kit の headEulerAngle X/Y/Z ──
  // 目が読めないとき（サングラス）の代わりの目であり、目が読めるときは
  // 「頭が落ちた・傾いた」を目より先に拾うこともある。
  /// 直近の角度。null は未取得。
  double? pitch, yaw, roll;

  /// 普段の姿勢。カメラの置き方（机の上から見上げる・車のスタンドで
  /// 斜めから）で角度の基準が変わるので、絶対値ではなく**普段からのずれ**で見る。
  /// ずれが小さい間だけゆっくり追従し、落ちている最中は動かさない。
  double? _pitchBase, _yawBase, _rollBase;

  /// 俯き・仰け反り・横倒しのどれかが [postureDeg] を超えて続いた時間。
  Duration postureOffFor = Duration.zero;
  DateTime? _postureOffSince;

  /// 前から目を離したまま続いた時間（横を向く・手元を見る）。車モードのときだけ意味を持つ。
  Duration lookAwayFor = Duration.zero;
  DateTime? _lookAwaySince;

  /// 車で使っているか（StatsService.carMode を映す）。脇見はこのときだけ。
  bool carMode = false;

  /// 脇見が [lookAwayAfter] 続いた。UI が一段弱い知らせを出す（エッジ）。
  /// 向き直ると false に戻り、[lookAwayCooldown] は再び出さない。
  bool lookAwayAlert = false;
  DateTime? _lastLookAwayAlertAt;

  /// 目が読めない（サングラス等）。顔は見えているのに、顔が現れてから
  /// 一度も「開いている」を見ていない状態が [eyesUnreadableAfter] 続いたら立つ。
  /// 立っている間は目の閉じでは鳴らさず、姿勢だけで見張る。
  bool eyesUnreadable = false;
  DateTime? _faceSince;
  DateTime? _seenOpenAt;

  /// いま鳴っている理由。'eyes'（目）か 'posture'（姿勢）。止め方が違う——
  /// 目なら目を開ける、姿勢なら姿勢を戻す。
  String? get alarmCause => _eyeAlarm
      ? 'eyes'
      : _postureAlarm
      ? 'posture'
      : null;
  DateTime? _postureOkSince;

  /// 直近のフレームの明るさ（0〜255、Y 成分の平均）。前面カメラの経路だけ。
  /// 暗くて顔が消えたときに「画面で照らす」判断に使う。
  double? frameLuma;

  static const postureDeg = 22.0;
  static const lookAwayDeg = 35.0;
  /// 前から目を離して 2 秒。100-Car 研究（Klauer ら 2006, NHTSA）で、
  /// 前方から 2 秒を超えて目を離すと事故・ニアミスの危険がおよそ倍になる。
  static const lookAwayAfter = Duration(seconds: 2);
  static const lookAwayCooldown = Duration(seconds: 10);
  static const eyesUnreadableAfter = Duration(seconds: 10);
  static const seenOpenAbove = 0.5;

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
  static const _perclosAlarmRatio =
      0.15; // Product heuristic; requires device validation.
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
  DateTime? _perclosStartedAt;

  /// アラーム中、目が開いたと認めるまでの時間。
  ///
  /// 以前は1フレームでも開けば止めていた。寝ぼけて目を細めただけで止まり、
  /// そのまま二度寝する。目覚まし時計の「計算問題を解くまで止まらない」と
  /// 同じ理屈で、カメラが「開いている」を続けて見るまで止めない。
  /// このアプリにしか作れない止め方。
  static const eyesOpenToStop = Duration(seconds: 3);
  DateTime? _eyesOpenSince;

  /// アラーム中に目を開け続けている時間（画面で「あと N 秒」を出すため）。
  Duration openFor = Duration.zero;

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
    if (state == DetectorState.starting || state == DetectorState.watching) {
      return;
    }
    faceTarget.reset();
    noFaceSeen = true;
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
      _eyeAlarm = false;
      _postureAlarm = false;
      history.clear();
      _smoothingWindow.clear();
      _perclosWindow.clear();
      _perclosStartedAt = null;
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
        notificationText: AppLanguage.current.running,
        useBackCamera: useBackCamera,
        onFailed: (message) {
          // 背面での見張りが死んだ。黙って「検知中」を出し続けるより、
          // 見張れていないと言うほうがましなので、そのまま画面に出す。
          backgroundFailure = message;
          cameraPausedInBackground = true;
          notifyListeners();
        },
        onReading: (face, l, r) {
          if (state != DetectorState.watching &&
              state != DetectorState.starting) {
            return;
          }
          noteInput();
          if (!face) {
            noteFaceLost();
            _notify();
            return;
          }
          noteFaceSeen();
          // 未取得値は閉眼ではなく、目を判定できない状態として扱う。
          ingestEyes(l, r);
        },
        onPose: (p, y, r) {
          if (state == DetectorState.watching ||
              state == DetectorState.starting) {
            ingestPose(p, y, r);
          }
        },
      );
      state = DetectorState.watching;
      _lastInputAt = clock();
      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => checkInputHealth(),
      );
      // 起動中（starting）にホームを押されると handleAppPaused は何もせずに
      // 返るので、前面のカメラを抱えたまま背面に入り、見張りが止まる
      // （開いてすぐ他のアプリへ、という使い方で実際に起きた）。
      // 開き終えた時点で既に背面なら、その場で native に引き継ぐ。
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (NativeEye.isRunning &&
          !_handedOverToNative &&
          (lifecycle == AppLifecycleState.paused ||
              lifecycle == AppLifecycleState.hidden ||
              lifecycle == AppLifecycleState.detached)) {
        _handedOverToNative = true;
        await _handOverToNative();
      }
    } catch (_) {
      state = DetectorState.denied;
      await ScreenWake.release(_wakeKey);
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    _lastInputAt = _lastEyesAt = _lastPoseAt = null;
    inputStalled = false;
    cameraPausedInBackground = false;
    faceTarget.reset();
    _eyesClosedSince = _eyesOpenSince = null;
    openFor = Duration.zero;
    await NativeEye.stop('eye');
    await ScreenWake.release(_wakeKey);
    _eyeAlarm = false;
    _postureAlarm = false;
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
    _perclosStartedAt = null;
    perclos = 0;
    _resetPosture();
    pitch = yaw = roll = null;
    _pitchBase = _yawBase = _rollBase = null;
    eyesUnreadable = false;
    _faceSince = null;
    _seenOpenAt = null;
    frameLuma = null;
    notifyListeners();
  }

  void _resetPosture() {
    postureOffFor = Duration.zero;
    _postureOffSince = null;
    lookAwayFor = Duration.zero;
    _lookAwaySince = null;
    lookAwayAlert = false;
    _postureOkSince = null;
  }

  CameraController? get controller => _controller;

  /// アラーム中の外側のライト（フラッシュ）。前面では Flutter 側がカメラを
  /// 持っているので、そのコントローラでライトを点す。前面カメラにはライトが
  /// 無いので失敗し、背面（native に引き継いだ後）や見張っていないときは
  /// コントローラが無い。どちらも false を返し、呼び出し側が setTorchMode
  /// 経路へ回る。
  Future<bool> setTorch(bool on) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      return true;
    } catch (_) {
      return false;
    }
  }

  void setThresholdSeconds(int seconds) {
    closedThreshold = Duration(seconds: seconds.clamp(3, 60));
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
    noteFaceLost();
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
    faceTarget.reset();
    noteFaceLost();
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
      inputStalled = true;
      cameraPausedInBackground = true;
      debugPrint('カメラを開き直せなかった: $e');
    }
    notifyListeners();
  }

  /// Silences the current alarm and ignores closed-eye time for 3 minutes.
  void snooze() {
    _eyeAlarm = false;
    _postureAlarm = false;
    _eyesOpenSince = null;
    openFor = Duration.zero;
    _eyesClosedSince = null;
    closedFor = Duration.zero;
    _perclosWindow.clear();
    _perclosStartedAt = null;
    perclos = 0;
    _resetPosture();
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
  void ingestEyes(double? left, double? right) {
    if (left == null ||
        right == null ||
        !left.isFinite ||
        !right.isFinite ||
        left < 0 ||
        left > 1 ||
        right < 0 ||
        right > 1) {
      eyesUnreadable = true;
      _lastEyesAt = null;
      _eyesClosedSince = _eyesOpenSince = null;
      closedFor = openFor = Duration.zero;
      _smoothingWindow.clear();
      _perclosWindow.clear();
      _perclosStartedAt = null;
      perclos = 0;
      _notify(force: true);
      return;
    }
    _ingest(combineEyes(left, right));
  }

  /// 頭の角度ひとつぶんの判定。目と同じく、カメラ2経路の両方がここを通る。
  ///
  /// [pitchDeg] 俯き／仰け反り（X）、[yawDeg] 左右の向き（Y）、[rollDeg] 横倒し（Z）。
  /// 普段の姿勢からのずれで見るので、カメラの置き方には依らない。
  void ingestPose(double pitchDeg, double yawDeg, double rollDeg) {
    if (!pitchDeg.isFinite || !yawDeg.isFinite || !rollDeg.isFinite) return;
    final poseNow = clock();
    if (_lastPoseAt != null &&
        poseNow.difference(_lastPoseAt!) > const Duration(seconds: 2)) {
      _resetPosture();
    }
    _lastPoseAt = poseNow;
    pitch = pitchDeg;
    yaw = yawDeg;
    roll = rollDeg;
    final now = clock();
    final suppressed = _suppressUntil != null && now.isBefore(_suppressUntil!);
    final wasAlarming = alarmFiring;
    final hadPostureAlarm = _postureAlarm;

    // 基準。最初の値で置き、ずれが小さい間だけゆっくり寄せる（1/50）。
    // 落ちている最中に追従させると、落ちた姿勢が「普段」になってしまう。
    _pitchBase ??= pitchDeg;
    _yawBase ??= yawDeg;
    _rollBase ??= rollDeg;
    final dPitch = (pitchDeg - _pitchBase!).abs();
    final dRoll = (rollDeg - _rollBase!).abs();
    final dYaw = (yawDeg - _yawBase!).abs();
    if (dPitch < postureDeg / 2) {
      _pitchBase = _pitchBase! * 0.98 + pitchDeg * 0.02;
    }
    if (dRoll < postureDeg / 2) _rollBase = _rollBase! * 0.98 + rollDeg * 0.02;
    if (dYaw < lookAwayDeg / 2) _yawBase = _yawBase! * 0.98 + yawDeg * 0.02;

    // ── 俯き・仰け反り・横倒し ──
    final off = dPitch >= postureDeg || dRoll >= postureDeg;
    if (suppressed || !off) {
      _postureOffSince = null;
      postureOffFor = Duration.zero;
    } else {
      _postureOffSince ??= now;
      postureOffFor = now.difference(_postureOffSince!);
    }
    if (!_postureAlarm && !suppressed && postureOffFor >= closedThreshold) {
      _postureAlarm = true;
      _postureOkSince = null;
    }
    // 姿勢で鳴っているなら、姿勢が戻って 3 秒で止める（目と同じ長さ）。
    if (_postureAlarm) {
      if (off) {
        _postureOkSince = null;
      } else {
        _postureOkSince ??= now;
        if (now.difference(_postureOkSince!) >= eyesOpenToStop) {
          _postureAlarm = false;
          _postureOkSince = null;
        }
      }
    }

    // ── 脇見・手元見（車モードのみ） ──
    // 手元（膝の上のスマホ・落とした物）を見るのは俯き。ML Kit の X は上が正。
    // 居眠りの頭の落下も同じ向きだが、2 秒で一度知らせるのはどちらにも正しい。
    final lookingDown = pitchDeg - _pitchBase! <= -postureDeg;
    final away = carMode && (dYaw >= lookAwayDeg || lookingDown);
    if (!away || suppressed) {
      _lookAwaySince = null;
      lookAwayFor = Duration.zero;
      lookAwayAlert = false;
    } else {
      _lookAwaySince ??= now;
      lookAwayFor = now.difference(_lookAwaySince!);
      final cooled =
          _lastLookAwayAlertAt == null ||
          now.difference(_lastLookAwayAlertAt!) >= lookAwayCooldown;
      if (!alarmFiring && lookAwayFor >= lookAwayAfter && cooled) {
        lookAwayAlert = true;
        _lastLookAwayAlertAt = now;
      }
    }
    _notify(
      force:
          alarmFiring != wasAlarming ||
          hadPostureAlarm != _postureAlarm ||
          lookAwayAlert,
    );
  }

  /// 顔を見失った。
  ///
  /// 見失っている間は「閉じている」とも「開いている」とも言えない。
  /// ここで閉眼タイマーをリセットしないと、目を閉じたまま顔が外れて戻って
  /// きたときに、外れていた時間まで閉眼として数えてしまう（Web 版は
  /// 最初からリセットしていた。Android だけ抜けていた）。
  /// 観測が途切れたので PERCLOS の窓も取り直す。
  /// 鳴っているアラームは止めない——顔を隠せば止まる、では困る。
  void noteFaceLost() {
    final changed = !noFaceSeen;
    noFaceSeen = true;
    _lastEyesAt = _lastPoseAt = null;
    _smoothingWindow.clear();
    _perclosWindow.clear();
    _perclosStartedAt = null;
    perclos = 0;
    _noFaceSince ??= clock();
    // 顔が見えないのは「開いている」ではない。開けている時間は積まない。
    _eyesOpenSince = null;
    openFor = Duration.zero;
    _eyesClosedSince = null;
    closedFor = Duration.zero;
    // 姿勢も同じ。見えていない間の時間は積まない。
    // 「目が読めるか」も顔が戻ってから数え直す（サングラスを掛けて戻る人）。
    _resetPosture();
    _faceSince = null;
    _seenOpenAt = null;
    eyesUnreadable = false;
    if (changed) _notify(force: true);
  }

  DateTime? _noFaceSince;

  /// 顔が戻った。[noteFaceLost] の対。両方の経路がここを通る。
  void noteFaceSeen() {
    final changed = noFaceSeen;
    noFaceSeen = false;
    _noFaceSince = null;
    _faceSince ??= clock();
    if (changed) _notify(force: true);
  }

  /// 顔を3秒以上見失っている。よくある原因（眼鏡の反射・マスク・暗さ）を
  /// 画面で伝えるための目安。一瞬の見失いでいちいち出すと煩い。
  bool get faceLostLong =>
      _noFaceSince != null &&
      clock().difference(_noFaceSince!) >= const Duration(seconds: 3);

  void _ingest(double raw) {
    final sampleNow = clock();
    if (_lastEyesAt != null &&
        sampleNow.difference(_lastEyesAt!) > const Duration(seconds: 2)) {
      _eyesClosedSince = _eyesOpenSince = null;
      closedFor = openFor = Duration.zero;
      _smoothingWindow.clear();
      _perclosWindow.clear();
      _perclosStartedAt = null;
    }
    _lastEyesAt = sampleNow;
    eyesUnreadable = false;
    // 顔が現れてから一度でも「開いている」を見たか。見ていない目の
    // 「閉」は信じない（サングラス・濃い眼鏡・小さすぎる顔）。
    if (raw > seenOpenAbove) {
      _seenOpenAt = clock();
      eyesUnreadable = false;
    } else if (_seenOpenAt == null && _faceSince != null) {
      if (clock().difference(_faceSince!) >= eyesUnreadableAfter) {
        eyesUnreadable = true;
      }
    }
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
    final hadEyeAlarm = _eyeAlarm;

    if (suppressed) {
      _eyesClosedSince = null;
      closedFor = Duration.zero;
    } else if (_seenOpenAt == null) {
      // まだ一度も開いた目を見ていない。閉じているのか読めないのか
      // 区別できないので、閉眼時間は積まない（姿勢の側が見張る）。
      _eyesClosedSince = null;
      closedFor = Duration.zero;
    } else if (eyeOpenness < openThreshold) {
      _eyesClosedSince ??= now;
      closedFor = now.difference(_eyesClosedSince!);
      // 閉じたら「開けている時間」は振り出しに戻る。
      _eyesOpenSince = null;
      openFor = Duration.zero;
    } else {
      _eyesClosedSince = null;
      closedFor = Duration.zero;
      if (_eyeAlarm) {
        _eyesOpenSince ??= now;
        openFor = now.difference(_eyesOpenSince!);
        if (openFor >= eyesOpenToStop) {
          _eyeAlarm = false;
          _eyesOpenSince = null;
          openFor = Duration.zero;
        }
      }
    }

    if (suppressed || _seenOpenAt == null || _eyeAlarm) {
      _perclosWindow.clear();
      _perclosStartedAt = null;
      perclos = 0;
    } else {
      _perclosStartedAt ??= now;
      _perclosWindow.add(_TimedSample(now, eyeOpenness));
      final cutoff = now.subtract(_perclosWarmUp);
      // Keep the interval straddling the boundary; weight by elapsed time,
      // not by frame count. Missing input resets the window above.
      while (_perclosWindow.length > 1 &&
          !_perclosWindow[1].time.isAfter(cutoff)) {
        _perclosWindow.removeAt(0);
      }
      var validUs = 0;
      var closedUs = 0;
      for (var i = 0; i + 1 < _perclosWindow.length; i++) {
        final sample = _perclosWindow[i];
        final begin = sample.time.isBefore(cutoff) ? cutoff : sample.time;
        final us = _perclosWindow[i + 1].time.difference(begin).inMicroseconds;
        if (us <= 0) continue;
        validUs += us;
        if (sample.openness < _perclosCloseThreshold) closedUs += us;
      }
      perclos = validUs == 0 ? 0 : closedUs / validUs;
    }
    final perclosReady =
        _perclosStartedAt != null &&
        now.difference(_perclosStartedAt!) >= _perclosWarmUp &&
        _perclosWindow.length >= _perclosMinSamples;
    if (!_eyeAlarm && !suppressed) {
      final byPerclos = perclosReady && perclos >= _perclosAlarmRatio;
      if (closedFor >= closedThreshold || byPerclos) {
        _eyeAlarm = true;
        _eyesOpenSince = null;
        openFor = Duration.zero;
        if (byPerclos) {
          _perclosWindow.clear();
          _perclosStartedAt = null;
          perclos = 0;
        }
      }
    }
    // 背面では UI が居ないので、鳴らす判断の変化だけは必ず通す。
    _notify(force: alarmFiring != wasAlarming || hadEyeAlarm != _eyeAlarm);
  }

  /// Y 成分（明るさ）の平均。64 画素ごとに拾うだけなので安い。
  /// 暗くて顔が消えたのか、席を外したのかを分けるために使う。
  static double? _meanLuma(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return null;
    var sum = 0;
    var n = 0;
    for (var i = 0; i < bytes.length; i += 64) {
      sum += bytes[i];
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _controller == null) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _minFrameGap) return;
    _lastFrameAt = now;
    _busy = true;
    final frameController = _controller;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) return;
      frameLuma = _meanLuma(image);
      final faces = await _faceDetector.processImage(inputImage);
      if (_controller != frameController) return;
      noteInput();
      final selected = faceTarget.select(faces);
      final wasAlarming = alarmFiring;
      final hadFace = !noFaceSeen;
      if (selected == null) {
        noteFaceLost();
      } else {
        noteFaceSeen();
        final face = selected;
        // 読めない目（null）も数える。native 経路と同じ扱い。
        ingestEyes(face.leftEyeOpenProbability, face.rightEyeOpenProbability);
        final px = face.headEulerAngleX, py = face.headEulerAngleY;
        final pz = face.headEulerAngleZ;
        if (px != null && py != null && pz != null) ingestPose(px, py, pz);
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
    _healthTimer?.cancel();
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
