import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'road_logic.dart';

/// 物体検出モデル。どちらも COCO・後処理込み・入力 uint8・Apache-2.0。
/// 出力の並びも同じ（枠 [1,N,4]・クラス [1,N]・スコア [1,N]・個数 [1]）。
enum RoadModel {
  /// SSD MobileNet v1 量子化（300×300、4MB）。PC で 25ms。どの端末でも回る。
  ssd('assets/models/ssd_mobilenet_v1_coco.tflite', 300, 10, 0.45),

  /// EfficientDet-Lite2（448×448、7.5MB）。PC で 119ms。遠い車に強い。
  /// 実測（tools/road_eval/range_test.py）: 中央の切り出しと組み合わせて、
  /// 画面幅 8%（乗用車で約 17m）の車をスコア 0.52 で見つける。SSD は 10%（約 13m）から。
  lite2('assets/models/efficientdet_lite2_coco.tflite', 448, 25, 0.4);

  const RoadModel(this.asset, this.size, this.maxDetections, this.minScore);
  final String asset;
  final int size;
  final int maxDetections;
  final double minScore;
}

/// 前の車を探すときに切り出す範囲（正立した画面に対する 0〜1）。
/// 前の車はほぼ必ず中央にいる。中央だけを入力に広げると、同じモデルでも
/// 小さい（遠い）車が 2 倍の大きさで写り、見つけられる距離が伸びる。
class RoadRoi {
  const RoadRoi(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
  static const full = RoadRoi(0, 0, 1, 1);
  static const center = RoadRoi(0.25, 0.25, 0.5, 0.5);
}

/// カメラの 1 フレームから車・人・信号を見つける（端末内で推論。映像はどこへも送らない）。
class RoadDetector {
  RoadModel model = RoadModel.ssd;
  Interpreter? _interp;
  IsolateInterpreter? _iso;
  Uint8List _input = Uint8List(RoadModel.ssd.size * RoadModel.ssd.size * 3);

  /// 直近の入力（正立・切り出し後の RGB）。信号の色を読むのに使う。
  Uint8List get lastRgb => _input;
  int get size => model.size;

  /// 直近の推論にかかった時間（ms）。
  int lastMs = 0;

  Future<void> load([RoadModel m = RoadModel.ssd]) async {
    await close();
    model = m;
    final interp = await Interpreter.fromAsset(
      m.asset,
      options: InterpreterOptions()..threads = 2,
    );
    _interp = interp;
    _iso = await IsolateInterpreter.create(address: interp.address);
    _input = Uint8List(m.size * m.size * 3);
  }

  /// 速い端末なら Lite2、遅ければ SSD。Lite2 を 3 回試し、1 回 [budgetMs] を
  /// 超えるなら SSD に替える。毎秒 4 回回らないと TTC の点が足りない（最小 4 点・0.6 秒）。
  Future<RoadModel> loadBest({int budgetMs = 300}) async {
    try {
      await load(RoadModel.lite2);
      final iso = _iso!;
      final sw = Stopwatch();
      for (var i = 0; i < 3; i++) {
        final out = _outputs();
        sw.start();
        await iso.runForMultipleInputs(
          [_input.reshape([1, size, size, 3])],
          out,
        );
        sw.stop();
      }
      if (sw.elapsedMilliseconds / 3 <= budgetMs) return model;
    } catch (_) {}
    await load(RoadModel.ssd);
    return model;
  }

  Map<int, Object> _outputs() {
    final n = model.maxDetections;
    return {
      0: [List.generate(n, (_) => List.filled(4, 0.0))],
      1: [List.filled(n, 0.0)],
      2: [List.filled(n, 0.0)],
      3: [0.0],
    };
  }

  /// [rotation] はフレームを正立させるための時計回りの角度（0/90/180/270）。
  /// [roi] を渡すとその範囲だけを見て、枠は画面全体の座標に戻して返す。
  Future<List<RoadObject>> detect(
    CameraImage img,
    int rotation, {
    RoadRoi roi = RoadRoi.full,
  }) async {
    final iso = _iso;
    if (iso == null) return const [];
    _fill(img, rotation, _input, size, roi);
    final out = _outputs();
    final sw = Stopwatch()..start();
    await iso.runForMultipleInputs([_input.reshape([1, size, size, 3])], out);
    lastMs = sw.elapsedMilliseconds;
    final boxes = (out[0]! as List)[0] as List;
    final classes = (out[1]! as List)[0] as List<double>;
    final scores = (out[2]! as List)[0] as List<double>;
    final count = ((out[3]! as List)[0] as double).toInt().clamp(0, model.maxDetections);
    final res = <RoadObject>[];
    for (var i = 0; i < count; i++) {
      final s = scores[i];
      if (s < model.minScore) continue;
      final kind = kindFromCoco(classes[i].round());
      if (kind == RoadKind.other) continue;
      final b = (boxes[i] as List<double>); // ymin, xmin, ymax, xmax（切り出しの中で 0〜1）
      res.add(
        RoadObject(
          kind,
          s,
          roi.left + b[1] * roi.width,
          roi.top + b[0] * roi.height,
          roi.left + b[3] * roi.width,
          roi.top + b[2] * roi.height,
        ),
      );
    }
    return res;
  }

  /// 画面全体を小さな RGB に縮めたもの（推論はしない）。車線の白線を探すのに使う。
  Uint8List fullFrame(CameraImage img, int rotation, int outSize) {
    final out = Uint8List(outSize * outSize * 3);
    _fill(img, rotation, out, outSize, RoadRoi.full);
    return out;
  }

  static void _fill(CameraImage img, int rotation, Uint8List out, int outSize, RoadRoi roi) {
    final yP = img.planes[0], uP = img.planes[1], vP = img.planes[2];
    yuvToRgb(
      out: out,
      outSize: outSize,
      width: img.width,
      height: img.height,
      y: yP.bytes,
      yRow: yP.bytesPerRow,
      u: uP.bytes,
      v: vP.bytes,
      uvRow: uP.bytesPerRow,
      uvPixel: uP.bytesPerPixel ?? 1,
      rotation: rotation,
      roi: roi,
    );
  }

  /// 枠の中の RGB を取り出す（信号の色を読む用。全体を見ているときだけ使う）。
  List<int> crop(RoadObject o) {
    final s = size;
    final x0 = (o.left * s).floor().clamp(0, s - 1);
    final x1 = (o.right * s).ceil().clamp(1, s);
    final y0 = (o.top * s).floor().clamp(0, s - 1);
    final y1 = (o.bottom * s).ceil().clamp(1, s);
    final out = <int>[];
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * s + x) * 3;
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

/// YUV420 を、時計回りに [rotation] 度回して正立させ、その [roi] の範囲を
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
  RoadRoi roi = RoadRoi.full,
}) {
  final w = width, h = height;
  // 正立後の幅・高さ
  final rw = rotation % 180 == 0 ? w : h;
  final rh = rotation % 180 == 0 ? h : w;
  final rx0 = (roi.left * rw).floor(), ry0 = (roi.top * rh).floor();
  final cw = (roi.width * rw).floor(), ch = (roi.height * rh).floor();
  var o = 0;
  for (var oy = 0; oy < outSize; oy++) {
    final ry = ry0 + oy * ch ~/ outSize;
    for (var ox = 0; ox < outSize; ox++) {
      final rx = rx0 + ox * cw ~/ outSize;
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
