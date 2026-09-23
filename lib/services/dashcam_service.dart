import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// ドラレコ。背面カメラで [segment] ずつ録り、新しい [keep] 本だけ残して
/// 古いものから上書きする。衝撃（[impactG] 以上）か「保護」ボタンで、
/// 直前の 1 本と録画中の 1 本を locked/ へ移し、上書きから外す。
///
/// - カメラは同時に 1 つしか開けないので、居眠りの見張りとは排他。
/// - 画面を開いている間だけ録る（camera プラグインが Activity に縛られる。
///   背面での録画は EyeService と同じく native の Camera2 が要る。別作業）。
/// - 区切りの付け替えで 1 秒弱の抜けが出る。
/// - 音は録らない。車内の会話まで残すのは頼まれていない。
/// - 映像は端末の中（アプリ専用の保存場所）だけ。外へは本人が共有したときだけ出る。
class DashcamService extends ChangeNotifier {
  static const segment = Duration(seconds: 60);
  static const keep = 10;

  /// 重力を除いた加速度の大きさ。急ブレーキは 1G 前後、衝突は数 G。
  /// スタンドの揺れ・段差で保護だらけにならない高さに置く。実車では未測定。
  static const impactG = 2.5;

  CameraController? controller;
  bool recording = false;
  String? error;
  DateTime? segmentStartedAt;
  List<File> loopClips = [];
  List<File> lockedClips = [];

  Timer? _timer;
  StreamSubscription<UserAccelerometerEvent>? _accel;
  bool _lockCurrent = false;
  bool _rotating = false;
  DateTime? _lastImpactAt;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/dashcam/$name');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> refresh() async {
    loopClips = _sorted(await _dir('loop'));
    lockedClips = _sorted(await _dir('locked'));
    _notify();
  }

  static List<File> _sorted(Directory d) {
    final files = d.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// 新しい順に並べたとき、[keep] 本を超えたぶん（消す対象）。
  @visibleForTesting
  static List<String> overflow(List<String> paths, int keep) {
    final sorted = [...paths]..sort((a, b) => b.compareTo(a));
    return sorted.length <= keep ? const [] : sorted.sublist(keep);
  }

  static String stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  Future<void> start() async {
    if (recording) return;
    error = null;
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await c.initialize();
      controller = c;
      await c.startVideoRecording();
      segmentStartedAt = DateTime.now();
      recording = true;
      await WakelockPlus.enable();
      _timer = Timer.periodic(segment, (_) => unawaited(_rotate()));
      _accel = userAccelerometerEventStream().listen(_onAccel);
    } catch (e) {
      error = '$e';
      await _teardown();
    }
    _notify();
  }

  void _onAccel(UserAccelerometerEvent e) {
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.81;
    if (g < impactG) return;
    final now = DateTime.now();
    if (_lastImpactAt != null &&
        now.difference(_lastImpactAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastImpactAt = now;
    unawaited(protect());
  }

  /// 直前の 1 本を保護し、録画中の 1 本も区切ったときに保護する。
  Future<void> protect() async {
    if (!recording) return;
    _lockCurrent = true;
    final loop = _sorted(await _dir('loop'));
    if (loop.isNotEmpty) await _moveToLocked(loop.first);
    await refresh();
  }

  Future<void> _moveToLocked(File f) async {
    final locked = await _dir('locked');
    final name = f.uri.pathSegments.last;
    await f.rename('${locked.path}/$name');
  }

  Future<void> _rotate({bool restart = true}) async {
    final c = controller;
    if (c == null || _rotating || !c.value.isRecordingVideo) return;
    _rotating = true;
    try {
      final started = segmentStartedAt ?? DateTime.now();
      final x = await c.stopVideoRecording();
      if (restart) {
        await c.startVideoRecording();
        segmentStartedAt = DateTime.now();
      }
      final target = _lockCurrent ? await _dir('locked') : await _dir('loop');
      _lockCurrent = false;
      final dest = '${target.path}/${stamp(started)}.mp4';
      try {
        await File(x.path).rename(dest);
      } on FileSystemException {
        // 別ボリュームのキャッシュからは rename できない端末がある。
        await File(x.path).copy(dest);
        await File(x.path).delete();
      }
      final loop = await _dir('loop');
      for (final p in overflow(
        loop.listSync().whereType<File>().map((f) => f.path).toList(),
        keep,
      )) {
        await File(p).delete();
      }
    } catch (e) {
      error = '$e';
    } finally {
      _rotating = false;
      await refresh();
    }
  }

  Future<void> stop() async {
    if (!recording) return;
    _timer?.cancel();
    _timer = null;
    await _rotate(restart: false);
    await _teardown();
    _notify();
  }

  Future<void> _teardown() async {
    recording = false;
    _timer?.cancel();
    _timer = null;
    await _accel?.cancel();
    _accel = null;
    final c = controller;
    controller = null;
    await c?.dispose();
    await WakelockPlus.disable();
  }

  Future<void> delete(File f) async {
    if (await f.exists()) await f.delete();
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
