"""走行動画を、アプリと同じ物体検出モデルにかけて JSONL に書き出す。

アプリは毎秒 4 回だけ推論するので、ここでも 250ms ごとに 1 フレームを取る。
出力は tool/replay_road.dart がアプリと同じ判定（DriveJudge）で再生する。

  python tools/road_eval/detect_video.py drive.mp4 out.jsonl [ssd|lite2] [full|center]

アプリの前方モードと同じにするなら、速い端末: lite2 center、遅い端末: ssd center。

映像はこの PC の中で処理し、どこへも送らない。
"""
import json
import sys

import cv2
import numpy as np
import tensorflow as tf

MODELS = {
    'ssd': ('assets/models/ssd_mobilenet_v1_coco.tflite', 300, 0.45),
    'lite2': ('assets/models/efficientdet_lite2_coco.tflite', 448, 0.40),
}
# アプリの RoadRoi.center と同じ（横 25〜75%・縦 25〜75%）
ROIS = {'full': (0, 0, 1, 1), 'center': (0.25, 0.25, 0.5, 0.5)}
KEEP = {0: 'person', 1: 'bicycle', 2: 'car', 3: 'motorcycle', 5: 'bus', 7: 'truck', 9: 'trafficLight'}


def main(src, dst, model='ssd', roi='center', step_ms=250):
    path, size, min_score = MODELS[model]
    rl, rt, rw, rh = ROIS[roi]
    interp = tf.lite.Interpreter(path)
    interp.allocate_tensors()
    inp = interp.get_input_details()[0]['index']
    outs = [d['index'] for d in interp.get_output_details()]
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    every = max(1, round(fps * step_ms / 1000))
    n = 0
    with open(dst, 'w', encoding='utf-8') as f:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if n % every == 0:
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                H, W = rgb.shape[:2]
                rgb = rgb[int(H * rt):int(H * (rt + rh)), int(W * rl):int(W * (rl + rw))]
                x = cv2.resize(rgb, (size, size), interpolation=cv2.INTER_NEAREST)
                interp.set_tensor(inp, x[None].astype(np.uint8))
                interp.invoke()
                boxes, classes, scores, count = (interp.get_tensor(i) for i in outs)
                objs = []
                for k in range(int(count[0])):
                    c, s = int(classes[0][k]), float(scores[0][k])
                    if s < min_score or c not in KEEP:
                        continue
                    ymin, xmin, ymax, xmax = (float(v) for v in boxes[0][k])
                    # 切り出しの中の座標を、画面全体の座標に戻す（アプリと同じ）
                    xmin, xmax = rl + xmin * rw, rl + xmax * rw
                    ymin, ymax = rt + ymin * rh, rt + ymax * rh
                    objs.append({'k': KEEP[c], 's': round(s, 3),
                                 'l': round(xmin, 4), 't': round(ymin, 4),
                                 'r': round(xmax, 4), 'b': round(ymax, 4)})
                f.write(json.dumps({'t': round(n / fps * 1000), 'o': objs}) + '\n')
            n += 1
    print(f'{n} frames, {n // every} analysed -> {dst}')


if __name__ == '__main__':
    main(*sys.argv[1:5])
