import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/breathing_detector.dart';
import '../theme/app_theme.dart';

/// 寝息検知（β）。マイクで規則的な寝息を拾う。設定の「開発中の機能」に置く。
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
                    onPressed:
                        breathing.state == MicState.listening ||
                            breathing.state == MicState.starting
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
            if (breathing.failure != null) ...[
              const SizedBox(height: 12),
              Text(breathing.failure!, style: TextStyle(color: c.accentAlert)),
            ],
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
