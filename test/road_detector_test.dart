import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/road_detector.dart';

void main() {
  // 横長 4×2 のフレーム。左上だけ白（Y=250）、残りは黒。色は無し（U=V=128）。
  // センサーは横向きに付いている想定。
  List<int> convert(int rotation) {
    final y = Uint8List.fromList([250, 0, 0, 0, 0, 0, 0, 0]);
    final uv = Uint8List.fromList([128, 128]);
    final out = Uint8List(4 * 4 * 3);
    yuvToRgb(
      out: out,
      outSize: 4,
      width: 4,
      height: 2,
      y: y,
      yRow: 4,
      u: uv,
      v: uv,
      uvRow: 2,
      uvPixel: 1,
      rotation: rotation,
    );
    // 白い画素の位置（出力の 4×4 のどこか）を返す
    return [
      for (var i = 0; i < 16; i++)
        if (out[i * 3] > 200) i,
    ];
  }

  test('回転なし: 白は左上', () {
    expect(convert(0).first, 0);
  });

  test('時計回りに 90°: 元の左上は右上へ', () {
    // 正立後は 2×4 の縦長。4×4 に引き伸ばすので、右半分の最上段。
    expect(convert(90), [2, 3]);
  });

  test('180°: 元の左上は右下へ', () {
    // 正立後は 4×2 の横長。縦に引き伸ばすので、右端の下 2 段。
    expect(convert(180), [11, 15]);
  });

  test('270°: 元の左上は左下へ', () {
    // 左半分の最下段
    expect(convert(270), [12, 13]);
  });

  test('向き: 縦持ちなら背面センサー 90° をそのまま、左に倒すと 0°', () {
    expect(uprightRotation(90, 0, 9.8), 90);
    expect(uprightRotation(90, 9.8, 0), 0);
    expect(uprightRotation(90, -9.8, 0), 180);
  });
}
