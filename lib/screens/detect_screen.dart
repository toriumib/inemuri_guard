import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/alarm_service.dart';
import '../services/drowsiness_detector.dart';
import '../services/alert_coordinator.dart';
import '../services/stats_service.dart';
import '../services/torch.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_stage.dart';
import '../widgets/sensitivity_control.dart';
import '../widgets/monitoring_status.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  late final DrowsinessDetector _detector;

  @override
  void initState() {
    super.initState();
    _detector = context.read<DrowsinessDetector>();
    // 保存した「使う場所」を、カメラの向き・車の機能・ライトへ配る。
    // 起動時にここを通らないと、背面カメラの設定が次の起動で効かない
    // （1.3.0 までそうなっていた）。
    _applyPlacement(context.read<StatsService>());
    // 前面ではカメラを持っている側（Flutter）しかライトを点せない。
    Torch.viaController = _detector.setTorch;
  }

  /// 保存した設定を、検知器と鳴らし側へ配る。使う場所（机／車）は検知画面、
  /// 裏向き（背面カメラ）は設定の「開発中」から変わる。どちらもここを通す。
  /// ライトは背面カメラのときだけ——前面のときは光が窓の外へ向く。
  void _applyPlacement(StatsService stats) {
    _detector.useBackCamera = stats.useBackCamera;
    _detector.carMode = stats.carMode;
    context.read<AlarmService>().useTorch =
        stats.useBackCamera && Torch.isSupported;
  }

  /// 地図アプリを開く。geo: を受けるアプリが無ければブラウザの Google マップに逃がす。
  Future<void> _openMaps() async {
    try {
      if (await launchUrl(
        Uri.parse('geo:0,0'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (e) {
      debugPrint('geo: launch failed: $e');
    }
    try {
      await launchUrl(
        Uri.parse('https://www.google.com/maps'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('maps web launch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detector = context.watch<DrowsinessDetector>();
    final alerts = context.watch<AlertCoordinator>();
    final alarm = context.read<AlarmService>();
    final stats = context.watch<StatsService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alerts.restAdvice) ...[
            _RestAdviceCard(onClose: alerts.dismissRestAdvice),
            const SizedBox(height: 16),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Web 版と同じ並び: 大きな映像 → 4つの読み取り → 大きなボタン。
                  // 机に置いて遠くから見る道具なので、映像と状態の一語が主役。
                  CameraStage(
                    detector: detector,
                    showPreview: stats.showCameraPreview,
                  ),
                  const SizedBox(height: 10),
                  ReadoutTiles(
                    detector: detector,
                    alertsToday: stats.alarmCount,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: detector.state == DetectorState.watching
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.accentAlert,
                              side: BorderSide(color: c.accentAlert),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await detector.stop();
                            },
                            child: const Text('止める'),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.accentGood,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: detector.state == DetectorState.starting
                                ? null
                                : () async {
                                    detector.setThresholdSeconds(
                                      stats.eyeThresholdSeconds,
                                    );
                                    await detector.start();
                                  },
                            child: Text(
                              detector.state == DetectorState.starting
                                  ? '起動中…'
                                  : '見張りを始める',
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => stats.setShowCameraPreview(
                            !stats.showCameraPreview,
                          ),
                          icon: Icon(
                            stats.showCameraPreview
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          label: Text(
                            stats.showCameraPreview ? '映像を隠す' : '映像を出す',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => alarm.preview(),
                          icon: const Icon(Icons.volume_up_outlined, size: 18),
                          label: const Text('音を試す'),
                        ),
                      ),
                    ],
                  ),
                  if (stats.carMode) ...[
                    const SizedBox(height: 10),
                    // 見張りは常駐サービスで続くので、マップを前に出してよい。
                    // それを知らないと「アプリを閉じたら止まる」と思って
                    // 画面を切り替えられない。
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openMaps(),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          detector.state == DetectorState.watching
                              ? 'マップを開く（見張りは続きます）'
                              : 'マップを開く',
                        ),
                      ),
                    ),
                  ],
                  if (detector.noFaceSeen &&
                      detector.state == DetectorState.watching &&
                      detector.faceLostLong) ...[
                    const SizedBox(height: 10),
                    // 3秒たっても見つからないなら、よくある原因を言う。
                    // 眼鏡の反射とマスクは、検出器がいちばん苦手にするもの。
                    Text(
                      '顔を検出できません。眼鏡の反射やマスクで見つけにくいことがあります。'
                      '顔を明るく、カメラを目の高さに。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.accentNap),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const MonitoringStatus(),
                  const SizedBox(height: 14),
                  const SensitivityControl(),
                  const SizedBox(height: 14),
                  Text('使う場所', style: Theme.of(context).textTheme.titleSmall),
                  RadioGroup<bool>(
                    groupValue: stats.carMode,
                    onChanged: (v) async {
                      if (v == null) return;
                      await stats.setCarMode(v);
                      _applyPlacement(stats);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: false,
                          title: Text('机の上'),
                          subtitle: Text('スマホを立てて自分に向けます。'),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: true,
                          title: Text('車'),
                          subtitle: Text(
                            'マップを見ながら見張れます。眠気を検知したら休憩できる場所を案内し、'
                            'よそ見も知らせます。',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats.carMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        '車内では補助としてのみ、自己責任で。見逃し・誤作動があり、注意義務の代わりには'
                        'なりません（利用規約 第4条）。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ),
                  if (detector.backgroundFailure != null) ...[
                    const SizedBox(height: 12),
                    // 見張れていないのに「検知中」と出したままにしない。
                    // 起きなかった理由が分からないのが、この道具で一番困る。
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.accentAlert.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: c.accentAlert),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '他のアプリを開いている間の見張りが止まりました'
                              '（${detector.backgroundFailure}）。'
                              'カメラの入力状態を確認し、停止してから再開してください。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (detector.state == DetectorState.denied) ...[
                    const SizedBox(height: 12),
                    Text(
                      'カメラを起動できませんでした。設定でカメラ権限を許可してください。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 車で眠気を検知したあとの案内。起こすだけで終わらせず、
/// どこで休むか（SA・PA・駐車場・路肩）と、探す入口（地図）まで出す。
/// 運転中に操作させないため、読むだけで済む文にし、閉じるまで残す。
class _RestAdviceCard extends StatelessWidget {
  final VoidCallback onClose;
  const _RestAdviceCard({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: c.accentNap.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_cafe_outlined, color: c.accentNap),
                const SizedBox(width: 8),
                Text('休憩しましょう', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '眠気を検知しました。次の SA・PA、駐車場、路肩など安全な場所に停めて、'
              '15〜20分でも休んでください。眠気は根性では消えません。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onClose, child: const Text('閉じる')),
            ),
          ],
        ),
      ),
    );
  }
}
