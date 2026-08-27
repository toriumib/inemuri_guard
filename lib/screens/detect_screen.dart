import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/alarm_service.dart';
import '../services/breathing_detector.dart';
import '../services/drowsiness_detector.dart';
import '../services/sleep_log_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/eye_sparkline.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  int thresholdSeconds = 10;
  bool _wasEyeAlarming = false;
  bool _wasBreathAlarming = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detector = context.watch<DrowsinessDetector>();
    final breathing = context.watch<BreathingDetector>();
    final alarm = context.read<AlarmService>();
    final stats = context.watch<StatsService>();
    final sleepLog = context.read<SleepLogService>();

    // React to each sensor's own alarm edge — start/stop the shared audible
    // alarm and log the event exactly once per episode. Deferred to after
    // the frame since this build runs from the sensors' own notifyListeners.
    if (detector.alarmFiring != _wasEyeAlarming) {
      final firing = detector.alarmFiring;
      _wasEyeAlarming = firing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (firing) {
          alarm.start(reason: '目を閉じたままの状態を検知しました');
          stats.bumpAlarm('目を閉じたままの状態を検知');
          sleepLog.add(SleepEventType.detected, note: '目の開閉');
        } else if (!breathing.alarmFiring) {
          alarm.stop();
        }
      });
    }
    if (breathing.alarmFiring != _wasBreathAlarming) {
      final firing = breathing.alarmFiring;
      _wasBreathAlarming = firing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (firing) {
          alarm.start(reason: '規則的な寝息のような音を検知しました');
          stats.bumpAlarm('寝息のような音を検知');
          sleepLog.add(SleepEventType.detected, note: '寝息');
        } else if (!detector.alarmFiring) {
          alarm.stop();
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '目の開閉で検知',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _PreviewToggle(
                        value: stats.showCameraPreview,
                        onChanged: stats.setShowCameraPreview,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '目を閉じ続けた時、または重いまばたきが増えたらアラームを鳴らします。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CameraPreviewFrame(
                        detector: detector,
                        showPreview: stats.showCameraPreview,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _MetricsColumn(detector: detector)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ChipThresholdPicker(
                    title: '何秒目を閉じたら起こす？',
                    options: const [10, 15, 20, 30],
                    value: thresholdSeconds,
                    suffix: '秒',
                    color: c.accentAlert,
                    onChanged: (v) {
                      setState(() => thresholdSeconds = v);
                      detector.setThresholdSeconds(v);
                    },
                  ),
                  const Divider(height: 28),
                  _ToneRow(alarm: alarm),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.accentAlert,
                            foregroundColor: c.accentAlertInk,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: detector.state == DetectorState.watching
                              ? null
                              : () async {
                                  detector.setThresholdSeconds(
                                    thresholdSeconds,
                                  );
                                  await detector.start();
                                },
                          child: Text(
                            detector.state == DetectorState.starting
                                ? '起動中…'
                                : '検知を開始',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: detector.state == DetectorState.watching
                              ? () async {
                                  await detector.stop();
                                  if (!breathing.alarmFiring) {
                                    await alarm.stop();
                                  }
                                }
                              : null,
                          child: const Text('停止'),
                        ),
                      ),
                    ],
                  ),
                  if (detector.state == DetectorState.denied) ...[
                    const SizedBox(height: 12),
                    Text(
                      'カメラを起動できませんでした。設定でカメラ権限を許可してください。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _LogList(stats: stats),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const BreathingCard(),
        ],
      ),
    );
  }
}

class BreathingCard extends StatefulWidget {
  const BreathingCard({super.key});

  @override
  State<BreathingCard> createState() => _BreathingCardState();
}

class _BreathingCardState extends State<BreathingCard> {
  int thresholdSeconds = 20;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final breathing = context.watch<BreathingDetector>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('寝息センサー（マイク）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '静かで規則的な呼吸音が続いたら検知します。カメラと併用可。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '音量レベル',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${breathing.currentDb.toStringAsFixed(0)} dB',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: breathing.regularityScore.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(
                  breathing.regularityScore > 0.8 ? c.accentNap : c.accentGood,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '規則的な呼吸を検知している時間',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${breathing.regularFor.inSeconds}秒',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ChipThresholdPicker(
              title: '何秒続いたら起こす？',
              options: const [15, 20, 30, 45],
              value: thresholdSeconds,
              suffix: '秒',
              color: c.accentAlert,
              onChanged: (v) {
                setState(() => thresholdSeconds = v);
                breathing.setThresholdSeconds(v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentAlert,
                      foregroundColor: c.accentAlertInk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: breathing.state == MicState.listening
                        ? null
                        : () async {
                            breathing.setThresholdSeconds(thresholdSeconds);
                            await breathing.start();
                          },
                    child: Text(
                      breathing.state == MicState.starting
                          ? '起動中…'
                          : 'マイク検知を開始',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: breathing.state == MicState.listening
                        ? breathing.stop
                        : null,
                    child: const Text('停止'),
                  ),
                ),
              ],
            ),
            if (breathing.state == MicState.denied) ...[
              const SizedBox(height: 12),
              Text(
                'マイクを起動できませんでした。設定でマイク権限を許可してください。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small "eye" toggle to hide the live camera feed while detection keeps
/// running — for when the phone sits facing you but you don't want your own
/// face staring back, or you just want less on screen.
class _PreviewToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PreviewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: c.textDim,
            ),
            const SizedBox(width: 4),
            Text('映像', style: TextStyle(fontSize: 12.5, color: c.textDim)),
          ],
        ),
      ),
    );
  }
}

/// Big, tappable seconds picker shared by both sensor cards — replaces the
/// old dropdown, which was too small/fiddly to hit reliably.
class _ChipThresholdPicker extends StatelessWidget {
  final String title;
  final List<int> options;
  final int value;
  final String suffix;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ChipThresholdPicker({
    required this.title,
    required this.options,
    required this.value,
    required this.suffix,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(
                  '$o$suffix',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: value == o,
                onSelected: (_) => onChanged(o),
                selectedColor: color,
                labelStyle: TextStyle(
                  color: value == o ? Colors.white : c.text,
                ),
                backgroundColor: c.surface2,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToneRow extends StatelessWidget {
  final AlarmService alarm;
  const _ToneRow({required this.alarm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('アラーム音', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<AlarmTone>(
              value: alarm.tone,
              underline: const SizedBox(),
              items: AlarmTone.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) {
                if (t != null) alarm.setTone(t);
              },
            ),
            IconButton(
              tooltip: '音を確認',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: alarm.preview,
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraPreviewFrame extends StatelessWidget {
  final DrowsinessDetector detector;
  final bool showPreview;
  const _CameraPreviewFrame({
    required this.detector,
    required this.showPreview,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = detector.controller;
    final isLive = controller != null && controller.value.isInitialized;
    return Container(
      width: 108,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
        color: c.surface2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isLive && showPreview)
            CameraPreview(controller)
          else if (isLive)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: c.textDim,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '映像は非表示\n検知は継続中',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            Center(
              child: Text(
                'カメラ未起動\n「検知を開始」で\nアクセス許可',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (detector.state == DetectorState.watching)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricsColumn extends StatelessWidget {
  final DrowsinessDetector detector;
  const _MetricsColumn({required this.detector});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final openness = detector.eyeOpenness;
    final barColor = openness > 0.5
        ? c.accentGood
        : (openness > detector.openThreshold ? c.accentNap : c.accentAlert);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '目の開き',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '${(openness * 100).toStringAsFixed(0)}%',
              style: _mono(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: openness.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: c.surface2,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: CustomPaint(
            painter: EyeSparkline(
              values: detector.history.isEmpty ? [1, 1] : detector.history,
              lineColor: c.accentGood,
              fillColor: c.accentGood.withValues(alpha: 0.15),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '目を閉じている時間',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text('${detector.closedFor.inSeconds}秒', style: _mono(context)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '重いまばたき率',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '${(detector.perclos * 100).toStringAsFixed(0)}%',
              style: _mono(context),
            ),
          ],
        ),
        if (detector.noFaceSeen && detector.state == DetectorState.watching)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '顔を検出できません',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.accentNap),
            ),
          ),
      ],
    );
  }

  TextStyle _mono(BuildContext context) =>
      const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold);
}

class _LogList extends StatelessWidget {
  final StatsService stats;
  const _LogList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (stats.log.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text('検知履歴', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        for (final entry in stats.log)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
