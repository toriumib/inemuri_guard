"""物体検出モデルが「何 m 先の車から」見つけられるかを測る。

実写のバスを、画面幅の 5〜40% の大きさで灰色の路面に置き、各モデルの最高スコアを出す。
中央を切り出して拡大する（ROI）場合も比べる。

  python tools/road_eval/range_test.py 写真.jpg モデル1.tflite [モデル2.tflite ...]

幅 → 距離の目安: 乗用車（1.7m）・横の画角 65° なら 距離 ≈ 1.33 / 幅。
"""
import sys

import cv2
import numpy as np
import tensorflow as tf

VEHICLE = {2, 5, 7}  # car, bus, truck（COCO の 0 始まり）


def load(path):
    it = tf.lite.Interpreter(path)
    it.allocate_tensors()
    d = it.get_input_details()[0]
    outs = it.get_output_details()
    return it, d, outs


def best_vehicle(model, rgb):
    it, d, outs = model
    size = d['shape'][1]
    x = cv2.resize(rgb, (size, size), interpolation=cv2.INTER_AREA)
    it.set_tensor(d['index'], x[None].astype(d['dtype']))
    it.invoke()
    got = {}
    for o in outs:
        t = it.get_tensor(o['index'])
        got[t.shape] = got.get(t.shape, []) + [t]
    # 後処理込みのモデルは [1,N,4] boxes, [1,N] classes, [1,N] scores, [1] count
    arrs = [it.get_tensor(o['index']) for o in outs]
    boxes = next(a for a in arrs if a.ndim == 3)
    flat = [a for a in arrs if a.ndim == 2]
    count = int(next(a for a in arrs if a.ndim == 1)[0])
    # classes は整数値、scores は 0〜1 の小数で見分ける
    a, b = flat
    classes, scores = (a, b) if np.all(np.mod(a, 1) == 0) else (b, a)
    best = 0.0
    for k in range(count):
        if int(classes[0][k]) in VEHICLE:
            best = max(best, float(scores[0][k]))
    return best


def scene(bus, frac, W=1280, H=720):
    frame = np.full((H, W, 3), 100, np.uint8)
    frame[int(H * 0.55):, :] = 60
    bw = int(W * frac)
    bh = int(bw * bus.shape[0] / bus.shape[1])
    b = cv2.resize(bus, (bw, bh), interpolation=cv2.INTER_AREA)
    x0 = (W - bw) // 2
    y1 = int(H * 0.7)
    frame[y1 - bh:y1, x0:x0 + bw] = b
    return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)


def roi(rgb):
    """前の車がいそうな中央（横 50%・縦 25〜75%）だけを切り出す。"""
    H, W = rgb.shape[:2]
    return rgb[int(H * 0.25):int(H * 0.75), int(W * 0.25):int(W * 0.75)]


def main(photo, models):
    img = cv2.imread(photo)
    h, w = img.shape[:2]
    bus = img[int(h * 0.24):int(h * 0.70), int(w * 0.02):int(w * 0.97)]
    loaded = [(m.split('/')[-1].split('\\')[-1], load(m)) for m in models]
    fracs = [0.05, 0.08, 0.10, 0.13, 0.16, 0.20, 0.25, 0.30, 0.40]
    print('幅   距離目安  ' + '  '.join(f'{n[:18]:>18} 全体/中央' for n, _ in loaded))
    for f in fracs:
        rgb = scene(bus, f)
        cells = []
        for _, m in loaded:
            cells.append(f'{best_vehicle(m, rgb):.2f}/{best_vehicle(m, roi(rgb)):.2f}'.rjust(28))
        print(f'{f:.2f}  {1.33 / f:5.1f}m ' + ''.join(cells))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
