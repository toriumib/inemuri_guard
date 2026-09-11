import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../services/alarm_service.dart';
import '../services/pomodoro_service.dart';
import '../theme/app_theme.dart';
import 'range_slider_row.dart';
import 'ring_timer.dart';

/// ポモドーロのカード。仮眠タブの2枚目。
///
/// 区間の終わりは**静かに**知らせる。ここは作業の区切りであって、
/// 居眠りを叩き起こす場面ではない。[AlarmService.start] は使わず、
/// 一度だけの音（マナーモードを尊重）＋短い振動＋スナックバー。
/// 背面にいたときは [PomodoroService] が予約した通知が合図になる。
class PomodoroCard extends StatefulWidget {
  const PomodoroCard({super.key});

  @override
  State<PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends State<PomodoroCard> {
  late final PomodoroService _pomo;

  @override
  void initState() {
    super.initState();
    _pomo = context.read<PomodoroService>();
    _pomo.onPhaseEnd = _phaseEnded;
  }

  @override
  void dispose() {
    if (_pomo.onPhaseEnd == _phaseEnded) _pomo.onPhaseEnd = null;
    super.dispose();
  }

  Future<void> _phaseEnded(PomoPhase finished) async {
    if (!mounted) return;
    final alarm = context.read<AlarmService>();
    // preview はメディア音量で1回鳴らすだけ。アラーム経路は使わない。
    await alarm.preview();
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: [0, 300, 150, 300]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          finished == PomoPhase.work
              ? '作業時間が終わりました。休憩に入りましょう。'
              : '休憩が終わりました。次の作業へ。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pomo = context.watch<PomodoroService>();
    final work = pomo.phase == PomoPhase.work || pomo.phase == PomoPhase.idle;
    final ringColor = work ? c.accentAlert : c.accentNap;

    final String phaseLabel = switch (pomo.phase) {
      PomoPhase.idle => '「開始」で作業を始めます',
      PomoPhase.work => pomo.isPaused ? '一時停止中' : '作業中',
      PomoPhase.breakTime => pomo.isPaused ? '一時停止中' : '休憩中',
      PomoPhase.workDone => '作業が終わりました。「開始」で休憩へ',
      PomoPhase.breakDone => '休憩が終わりました。「開始」で次の作業へ',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ポモドーロ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '作業と休憩を区切ると集中が続き、眠気の波にも気づきやすくなります。'
              '区間が終わるたびに合図します。次の区間は自分で始めてください。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: RingTimerPainter(
                        fraction: pomo.fraction,
                        trackColor: c.surface2,
                        progressColor: ringColor,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pomo.formatted,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        if (pomo.round > 0)
                          Text(
                            '${pomo.round}回目',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                phaseLabel,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentAlert,
                      foregroundColor: c.accentAlertInk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: (pomo.isRunning || pomo.isPaused)
                        ? null
                        : () => pomo.start(),
                    child: const Text('開始'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: pomo.isRunning
                        ? () => pomo.pause()
                        : (pomo.isPaused ? () => pomo.resume() : null),
                    child: Text(pomo.isPaused ? '再開' : '一時停止'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: pomo.phase == PomoPhase.idle
                        ? null
                        : () => pomo.reset(),
                    child: const Text('リセット'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            RangeSliderRow(
              title: '作業',
              value: pomo.workMinutes,
              min: PomodoroService.minWork,
              max: PomodoroService.maxWork,
              step: 5,
              unit: '分',
              minLabel: '短く',
              maxLabel: '長く',
              color: c.accentAlert,
              onChanged: (v) => pomo.setWorkMinutes(v),
            ),
            const SizedBox(height: 8),
            RangeSliderRow(
              title: '休憩',
              value: pomo.breakMinutes,
              min: PomodoroService.minBreak,
              max: PomodoroService.maxBreak,
              unit: '分',
              minLabel: '短く',
              maxLabel: '長く',
              color: c.accentNap,
              onChanged: (v) => pomo.setBreakMinutes(v),
            ),
            const SizedBox(height: 10),
            Text(
              '他のアプリを開いている間に区間が終わったときは、通知で知らせます。'
              '省電力の仕組みで数分遅れることがあります。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12, color: c.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
