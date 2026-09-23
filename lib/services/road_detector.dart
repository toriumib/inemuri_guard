import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'road_logic.dart';

/// カメラの 1 フレームから車・人・信号を見つける（端末内で推論。映像はどこへも送らない）。
///
/// モデルは COCO SSD MobileNet v1 量子化版（300×300、後処理込み、Apache-2.0）。
/// 精度より「どの端末でも数 fps で回る」を取った。遠い車・夜・雨には弱い。
class RoadDetector {
  static const _asset = 'assets/models/ssd_mobilenet_v1_coco.tflite';
  static const size = 300;
  static const minScore = 0.45;

  Interpreter? _interp;
  IsolateInterpreter? _iso;
  final _input = Uint8List(size * size * 3);

  /// 直近の入力（正立・300×300 の RGB）。信号の色を読むのに使う。
  Uint8List get lastRgb => _input;

  Future<void> load() async {
    if (_interp != null) return;
    final interp = await Interpreter.fromAsset(
      _asset,
      options: InterpreterOptions()..threads = 2,
    );
    _interp = interp;
    _iso = await IsolateInterpreter.create(address: interp.address);
  }

  /// [rotation] はフレームを正立させるための時計回りの角度（0/90/180/270）。
  Future<List<RoadObject>> detect(CameraImage img, int rotation) async {
    final iso = _iso;
    if (iso == null) return const [];
    _toRgb(img, rotation);
    final boxes = [List.generate(10, (_) => List.filled(4, 0.0))];
    final classes = [List.filled(10, 0.0)];
    final scores = [List.filled(10, 0.0)];
    final count = [0.0];
    await iso.runForMultipleInputs(
      [_input.reshape([1, size, size, 3])],
      {0: boxes, 1: classes, 2: scores, 3: count},
    );
    final out = <RoadObject>[];
    final n = count[0].toInt().clamp(0, 10);
    for (var i = 0; i < n; i++) {
      final s = scores[0][i];
      if (s < minScore) continue;
      final kind = kindFromCoco(classes[0][i].round());
      if (kind == RoadKind.other) continue;
      final b = boxes[0][i]; // ymin, xmin, ymax, xmax
      out.add(RoadObject(kind, s, b[1], b[0], b[3], b[2]));
    }
    return out;
  }

  void _toRgb(CameraImage img, int rotation) {
    final yP = img.planes[0], uP = img.planes[1], vP = img.planes[2];
    yuvToRgb(
      out: _input,
      outSize: size,
      width: img.width,
      height: img.height,
      y: yP.bytes,
      yRow: yP.bytesPerRow,
      u: uP.bytes,
      v: vP.bytes,
      uvRow: uP.bytesPerRow,
      uvPixel: uP.bytesPerPixel ?? 1,
      rotation: rotation,
    );
  }

  /// 枠の中の RGB を取り出す（信号の色を読む用）。
  List<int> crop(RoadObject o) {
    final x0 = (o.left * size).floor().clamp(0, size - 1);
    final x1 = (o.right * size).ceil().clamp(1, size);
    final y0 = (o.top * size).floor().clamp(0, size - 1);
    final y1 = (o.bottom * size).ceil().clamp(1, size);
    final out = <int>[];
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * size + x) * 3;
        out
          ..add(_input[i])
          ..add(_input[i + 1])
          ..add(_input[i + 2]);
      }
    }
    return out;
  }

  Future<void> close() async {
    await _iso?.close();
    _interp?.close();
    _iso = null;
    _interp = null;
  }
}

/// 端末の向き（重力）とセンサーの取り付け角から、フレームを正立させる角度。
/// アプリは縦固定でも、車ではスマホを横に付けることが多いので重力で決める。
int uprightRotation(int sensorOrientation, double gx, double gy) {
  // 端末の回転（反時計回り、度）。縦持ち 0、左に倒す 90、逆さ 180、右に倒す 270。
  final int device;
  if (gy.abs() >= gx.abs()) {
    device = gy >= 0 ? 0 : 180;
  } else {
    device = gx >= 0 ? 90 : 270;
  }
  return (sensorOrientation - device + 360) % 360;
}

/// YUV420 を、時計回りに [rotation] 度回して正立させながら
/// [outSize]×[outSize] の RGB に縮める（最近傍）。テストできるよう外に出した。
void yuvToRgb({
  required Uint8List out,
  required int outSize,
  required int width,
  required int height,
  required Uint8List y,
  required int yRow,
  required Uint8List u,
  required Uint8List v,
  required int uvRow,
  required int uvPixel,
  required int rotation,
}) {
  final w = width, h = height;
  // 正立後の幅・高さ
  final rw = rotation % 180 == 0 ? w : h;
  final rh = rotation % 180 == 0 ? h : w;
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final ry = oy * rh ~/ outSize;
    for (var ox = 0; ox < outSize; ox++) {
      final rx = ox * rw ~/ outSize;
      // 正立座標 (rx, ry) → 元フレーム (x, yy)
      int x, yy;
      switch (rotation) {
        case 90:
          x = ry;
          yy = h - 1 - rx;
        case 180:
          x = w - 1 - rx;
          yy = h - 1 - ry;
        case 270:
          x = w - 1 - ry;
          yy = rx;
        default:
          x = rx;
          yy = ry;
      }
      final lum = y[yy * yRow + x];
      final uvi = (yy >> 1) * uvRow + (x >> 1) * uvPixel;
      final cu = u[uvi] - 128;
      final cv = v[uvi] - 128;
      out[o++] = (lum + 1.402 * cv).round().clamp(0, 255);
      out[o++] = (lum - 0.344 * cu - 0.714 * cv).round().clamp(0, 255);
      out[o++] = (lum + 1.772 * cu).round().clamp(0, 255);
    }
  }
}
