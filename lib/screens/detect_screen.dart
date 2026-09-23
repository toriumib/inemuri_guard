import '../l10n/app_language.dart';
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
import '../widgets/walk_light_card.dart';
import '../widgets/speed_limit_panel.dart';

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
        ).showSnackBar(SnackBar(content: Text(context.l10n.mapsFailed)));
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
          context.l10n.positionPhone,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          watching && detector.eyesAvailable
              ? context.l10n.continueWorking
              : context.l10n.positionHint,
        ),
        const SizedBox(height: 16),
        // 使う場所を最初に選ばせる。車の見張り（DDAW・ADDW・ISA）はこの製品の
        // いちばんの売りなのに、以前は「感度・使う場所を変える」の中に隠れていた。
        Text(
          context.l10n.placementTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.desk_outlined),
              label: Text(context.l10n.desk),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.directions_car_outlined),
              label: Text(context.l10n.car),
            ),
          ],
          selected: {stats.carMode},
          onSelectionChanged: (v) async {
            await stats.setCarMode(v.first);
            if (mounted) _applyPlacement(stats);
          },
        ),
        if (stats.carMode) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.carWatchSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
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
                ? context.l10n.preparing
                : watching
                ? context.l10n.stopMonitoring
                : context.l10n.startMonitoring,
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
                      SnackBar(content: Text(context.l10n.soundFailed)),
                    );
                  }
                }
              },
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(context.l10n.testSound),
            ),
            TextButton.icon(
              onPressed: () =>
                  stats.setShowCameraPreview(!stats.showCameraPreview),
              icon: Icon(
                stats.showCameraPreview
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(
                stats.showCameraPreview
                    ? context.l10n.hidePreview
                    : context.l10n.showPreview,
              ),
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
            label: Text(context.l10n.cameraPermission),
          ),
        if (watching && (detector.inputStalled || detector.faceLostLong))
          OutlinedButton.icon(
            onPressed: _recovering ? null : _retry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.reconnectCamera),
          ),
        const QuickSetupCard(),
        if (stats.showCameraPreview) ...[
          const SizedBox(height: 12),
          CameraStage(detector: detector, showPreview: true),
        ],
        const SpeedLimitPanel(),
        if (alerts.restAdvice)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.restSafely,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(context.l10n.restSafelyHint),
                  TextButton(
                    onPressed: alerts.dismissRestAdvice,
                    child: Text(context.l10n.close),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            key: const PageStorageKey('watch-options'),
            title: Text(context.l10n.watchOptions),
            subtitle: Text(
              context.l10n.optionsSummary(
                stats.sensitivity == DetectionSensitivity.sensitive
                    ? context.l10n.sensitivitySensitive
                    : stats.sensitivity == DetectionSensitivity.standard
                    ? context.l10n.sensitivityStandard
                    : context.l10n.sensitivityCustom,
                stats.carMode ? context.l10n.car : context.l10n.desk,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const SensitivityControl(),
              if (stats.carMode) ...[
                const _UnresponsiveCallTile(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.speedLimitToggle),
                  subtitle: Text(context.l10n.speedLimitHelp),
                  value: stats.speedLimitAlert,
                  onChanged: stats.setSpeedLimitAlert,
                ),
                Text(context.l10n.drivingWarning),
                OutlinedButton.icon(
                  onPressed: _maps,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(context.l10n.parkThenMaps),
                ),
              ],
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: Text(context.l10n.detectionDetails),
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
        const WalkLightCard(),
        const DashcamCard(),
      ],
    );
  }
}

/// ドライバー異常時対応: 反応が無いとき家族に電話する設定。
class _UnresponsiveCallTile extends StatelessWidget {
  const _UnresponsiveCallTile();

  Future<void> _edit(BuildContext context, StatsService stats, bool enable) async {
    final ctl = TextEditingController(text: stats.emergencyContact);
    final number = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unresponsiveCallToggle),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.emergencyContactLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    if (number == null || number.trim().isEmpty) return;
    // 発信の許可。断られてもダイヤル画面までは開ける（発信は本人が押す）。
    if (enable) await Permission.phone.request();
    await stats.setUnresponsiveCall(enable, number);
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final l = context.l10n;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.unresponsiveCallToggle),
      subtitle: Text(
        stats.emergencyContact.isEmpty
            ? l.unresponsiveCallHelp
            : '${stats.emergencyContact}\n${l.unresponsiveCallHelp}',
      ),
      value: stats.unresponsiveCall && stats.emergencyContact.isNotEmpty,
      onChanged: (v) => v
          ? _edit(context, stats, true)
          : stats.setUnresponsiveCall(false, stats.emergencyContact),
    );
  }
}
