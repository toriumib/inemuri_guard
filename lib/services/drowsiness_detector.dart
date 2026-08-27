import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, defaultTargetPlatform, TargetPlatform, WriteBuffer;
import 'package:flutter/widgets.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _controller;
  bool _busy = false;
  DateTime? _eyesClosedSince;
  DateTime? _suppressUntil;

  DetectorState state = DetectorState.idle;
  double eyeOpenness = 1.0; // 0 = fully closed, 1 = fully open (smoothed)
  Duration closedFor = Duration.zero;
  Duration closedThreshold = const Duration(seconds: 10);
  double openThreshold = 0.35;
  bool alarmFiring = false;
  bool noFaceSeen = false;

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
  double perclos = 0;

  Future<void> start() async {
    state = DetectorState.starting;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
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
      state = DetectorState.watching;
    } catch (_) {
      state = DetectorState.denied;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    alarmFiring = false;
    noFaceSeen = false;
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

  /// Silences the current alarm and ignores closed-eye time for 3 minutes.
  void snooze() {
    alarmFiring = false;
    _eyesClosedSince = null;
    closedFor = Duration.zero;
    _perclosWindow.clear();
    perclos = 0;
    _suppressUntil = DateTime.now().add(const Duration(minutes: 3));
    notifyListeners();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _controller == null) return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        noFaceSeen = true;
      } else {
        noFaceSeen = false;
        final face = faces.first;
        final l = face.leftEyeOpenProbability;
        final r = face.rightEyeOpenProbability;
        if (l != null && r != null) {
          final raw = (l + r) / 2;
          _smoothingWindow.add(raw);
          if (_smoothingWindow.length > _smoothingSize) {
            _smoothingWindow.removeAt(0);
          }
          eyeOpenness =
              _smoothingWindow.reduce((a, b) => a + b) /
              _smoothingWindow.length;
          history.add(eyeOpenness);
          if (history.length > historyMax) history.removeAt(0);

          final now = DateTime.now();
          final suppressed =
              _suppressUntil != null && now.isBefore(_suppressUntil!);
          if (suppressed) {
            _eyesClosedSince = null;
            closedFor = Duration.zero;
          } else if (eyeOpenness < openThreshold) {
            _eyesClosedSince ??= now;
            closedFor = now.difference(_eyesClosedSince!);
          } else {
            _eyesClosedSince = null;
            closedFor = Duration.zero;
            if (alarmFiring) {
              alarmFiring = false;
            }
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

          if (!alarmFiring &&
              (closedFor >= closedThreshold ||
                  (!suppressed &&
                      _perclosWindow.length >= _perclosMinSamples &&
                      perclos >= _perclosAlarmRatio))) {
            alarmFiring = true;
          }
        }
      }
      notifyListeners();
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
