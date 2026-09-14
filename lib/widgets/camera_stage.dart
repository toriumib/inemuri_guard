import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/drowsiness_detector.dart';
import '../theme/app_theme.dart';

/// Web 版の `.stage` と同じ作り。カメラ映像を 4:3 で大きく出し、
/// 左上に状態のバッジ、下に目の状態と閉じている時間、いちばん下に
/// しきい値までの進みを細い棒で。数字は横に並べず、映像の上に重ねる。
///
/// 机に置いて遠くから見る道具なので、小さな数字より「映像＋状態の一語」。
class CameraStage extends StatelessWidget {
  final DrowsinessDetector detector;
  final bool showPreview;
  const CameraStage({
    super.key,
    required this.detector,
    required this.showPreview,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = detector.controller;
    final isLive = controller != null && controller.value.isInitialized;
    final watching = detector.state == DetectorState.watching;
    final closed = detector.eyeOpenness < detector.openThreshold;
    final noFace = watching && detector.noFaceSeen;
    final thresholdMs = detector.closedThreshold.inMilliseconds;
    final progress = thresholdMs == 0
        ? 0.0
        : (detector.closedFor.inMilliseconds / thresholdMs).clamp(0.0, 1.0);

    // バッジ。Web と同じ語で、状態がひと目で分かるように。
    final (String badge, Color badgeColor) = !watching
        ? ('STOPPED', Colors.white54)
        : detector.alarmFiring
        ? ('WAKE UP', c.accentAlert)
        : noFace
        ? ('NO FACE', c.accentNap)
        : closed
        ? ('EYES CLOSED', c.accentAlert)
        : ('WATCHING', c.accentGood);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F0E),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isLive && showPreview)
              _CoverPreview(controller: controller)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    isLive
                        ? '映像は表示していません。検知は続いています。'
                        : (detector.state == DetectorState.starting
                              ? 'カメラを起動しています…'
                              : (detector.state == DetectorState.denied
                                    ? 'カメラを使えませんでした。許可を確認してください。'
                                    : '下のボタンを押すと始まります')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            // 上の帯: バッジ
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 下の帯: 目の状態と閉じている時間、しきい値までの棒
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: watching ? progress : 0,
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(
                          progress > 0.6 ? c.accentAlert : c.accentGood,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            !watching
                                ? '目 —'
                                : noFace
                                ? '顔 なし'
                                : '目 ${closed ? '閉' : '開'} '
                                      '${(detector.eyeOpenness * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          // 「閉じている時間」だと 360dp で左の文が「顔が…」に潰れる。
                          '閉じて '
                          '${(detector.closedFor.inMilliseconds / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4:3 の枠いっぱいに映像を敷く（BoxFit.cover）。
/// カメラのプレビューは端末によって縦横比が違うので、縦横を入れ替えた
/// 実寸の箱に入れてから枠に合わせて拡大する。
class _CoverPreview extends StatelessWidget {
  final CameraController controller;
  const _CoverPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        // previewSize は横向きで返るので縦横を入れ替える。
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Web 版の `.readout` と同じ4枚のタイル。EYES / CLOSED / FACE / ALERTS。
class ReadoutTiles extends StatelessWidget {
  final DrowsinessDetector detector;
  final int alertsToday;
  const ReadoutTiles({
    super.key,
    required this.detector,
    required this.alertsToday,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final watching = detector.state == DetectorState.watching;
    final closed = detector.eyeOpenness < detector.openThreshold;
    final hot = watching && (closed || detector.alarmFiring);
    return Row(
      children: [
        _Tile(
          label: 'EYES',
          // 顔が無いときの 100% は「開いている」ではなく「分からない」。
          value: watching && !detector.noFaceSeen
              ? '${(detector.eyeOpenness * 100).toStringAsFixed(0)}%'
              : '—',
          hot: hot,
        ),
        const SizedBox(width: 8),
        _Tile(
          label: 'CLOSED',
          value: '${(detector.closedFor.inMilliseconds / 1000).toStringAsFixed(1)}s',
          hot: hot,
        ),
        const SizedBox(width: 8),
        _Tile(
          label: 'FACE',
          value: !watching ? '—' : (detector.noFaceSeen ? 'なし' : '検出'),
          hot: watching && detector.noFaceSeen,
          hotColor: c.accentNap,
        ),
        const SizedBox(width: 8),
        _Tile(label: 'ALERTS', value: '$alertsToday', hot: false),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool hot;
  final Color? hotColor;
  const _Tile({
    required this.label,
    required this.value,
    required this.hot,
    this.hotColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Container(
        // 4 枚並ぶと 360dp の端末で 1 枚 56dp しか無い。左右の余白は詰め、
        // 文字は折り返さず縮める（実機で "CLO SED" "0..." に化けた）。
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: c.textDim,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: hot ? (hotColor ?? c.accentAlert) : c.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
