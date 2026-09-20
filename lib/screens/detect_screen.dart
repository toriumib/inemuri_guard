import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/alarm_service.dart';
import '../services/drowsiness_detector.dart';
import '../services/alert_coordinator.dart';
import '../services/stats_service.dart';
import '../services/torch.dart';
import '../services/device_readiness.dart';
import '../widgets/camera_stage.dart';
import '../widgets/sensitivity_control.dart';
import '../widgets/monitoring_status.dart';
import '../widgets/first_use_card.dart';
import '../widgets/quick_setup_card.dart';

/// Daily use needs no configuration. Diagnostics and optional modes stay folded.
class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});
  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen>
    with WidgetsBindingObserver {
  bool _resumeAfterPermission = false;
  bool _recovering = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || !_resumeAfterPermission) return;
    _resumeAfterPermission = false;
    if (await Permission.camera.isGranted && mounted) {
      final detector = context.read<DrowsinessDetector>();
      if (detector.state != DetectorState.watching &&
          detector.state != DetectorState.starting) {
        await _toggle();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final detector = context.read<DrowsinessDetector>();
    _applyPlacement(context.read<StatsService>());
    Torch.viaController = detector.setTorch;
  }

  void _applyPlacement(StatsService stats) {
    final detector = context.read<DrowsinessDetector>();
    detector.useBackCamera = stats.useBackCamera;
    detector.carMode = stats.carMode;
    context.read<AlarmService>().useTorch =
        stats.flashAlarm && stats.useBackCamera && Torch.isSupported;
  }

  Future<void> _toggle() async {
    final detector = context.read<DrowsinessDetector>();
    if (detector.state == DetectorState.watching) {
      await detector.stop();
    } else {
      detector.setThresholdSeconds(
        context.read<StatsService>().eyeThresholdSeconds,
      );
      await detector.start();
    }
    if (mounted) await context.read<DeviceReadiness>().refresh();
  }

  Future<void> _retry() async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      final detector = context.read<DrowsinessDetector>();
      await detector.stop();
      if (mounted) await _toggle();
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _maps() async {
    try {
      final ok = await launchUrl(
        Uri.parse('geo:0,0'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(
        Uri.parse('https://www.google.com/maps'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地図を開けませんでした。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detector = context.watch<DrowsinessDetector>();
    final stats = context.watch<StatsService>();
    final alerts = context.watch<AlertCoordinator>();
    final watching = detector.state == DetectorState.watching;
    final starting = detector.state == DetectorState.starting;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FirstUseCard(),
        Text(
          'スマホを立てて、自分に向けるだけ。',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          watching && detector.eyesAvailable
              ? '見張っています。そのまま作業を続けられます。'
              : '顔と目が映る位置に置いてください。細かな設定は後から変えられます。',
        ),
        const SizedBox(height: 16),
        const MonitoringStatus(),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('watch-toggle'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: starting ? null : _toggle,
          icon: Icon(
            watching ? Icons.stop_circle_outlined : Icons.visibility_outlined,
          ),
          label: Text(
            starting
                ? '準備しています…'
                : watching
                ? '見張りを止める'
                : '見張りを始める',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await context.read<AlarmService>().preview();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('音を再生できませんでした。音量の設定を確認してください。'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('音を試す'),
            ),
            TextButton.icon(
              onPressed: () =>
                  stats.setShowCameraPreview(!stats.showCameraPreview),
              icon: Icon(
                stats.showCameraPreview
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(stats.showCameraPreview ? '映像を隠す' : '映像を確認'),
            ),
          ],
        ),
        if (detector.state == DetectorState.denied)
          OutlinedButton.icon(
            onPressed: () async {
              _resumeAfterPermission = true;
              final opened = await openAppSettings();
              if (!opened) _resumeAfterPermission = false;
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('カメラの許可を設定する'),
          ),
        if (watching && (detector.inputStalled || detector.faceLostLong))
          OutlinedButton.icon(
            onPressed: _recovering ? null : _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('カメラをつなぎ直す'),
          ),
        const QuickSetupCard(),
        if (stats.showCameraPreview) ...[
          const SizedBox(height: 12),
          CameraStage(detector: detector, showPreview: true),
        ],
        if (alerts.restAdvice)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '安全な場所で休憩しましょう',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('眠気を感じたら、安全な場所に停めて休んでください。地図は停車してから操作してください。'),
                  TextButton(
                    onPressed: alerts.dismissRestAdvice,
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            key: const PageStorageKey('watch-options'),
            title: const Text('感度・使う場所を変える'),
            subtitle: Text(
              '${stats.sensitivity == DetectionSensitivity.sensitive
                  ? '敏感'
                  : stats.sensitivity == DetectionSensitivity.standard
                  ? '標準'
                  : '詳細設定'}・${stats.carMode ? '車' : '机の上'}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const SensitivityControl(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final car in [false, true])
                    ChoiceChip(
                      label: Text(car ? '車' : '机の上'),
                      selected: stats.carMode == car,
                      onSelected: (_) async {
                        await stats.setCarMode(car);
                        if (mounted) _applyPlacement(stats);
                      },
                    ),
                ],
              ),
              if (stats.carMode) ...[
                const Text('運転中は操作しないでください。補助の道具であり、安全を保証するものではありません。'),
                OutlinedButton.icon(
                  onPressed: _maps,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('停車して地図を開く'),
                ),
              ],
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('検知の詳しい情報'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ReadoutTiles(
                  detector: detector,
                  alertsToday: stats.alarmCount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
