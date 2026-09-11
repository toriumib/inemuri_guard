import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/hydration_service.dart';
import '../theme/app_theme.dart';

/// 水分補給のリマインダー設定。設定タブ。
///
/// 仮眠タブではなく設定にあるのは、これが常設のリマインダーであって
/// セッション型のタイマーではないから。
class HydrationCard extends StatelessWidget {
  const HydrationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = context.watch<HydrationService>();
    final next = h.nextAt;

    String two(int n) => n.toString().padLeft(2, '0');
    String nextText() {
      if (!h.enabled) return '';
      if (next == null) return '時間帯の設定を見直してください（開始が終了より前になっているか）。';
      final sameDay =
          next.day == DateTime.now().day && next.month == DateTime.now().month;
      return '次は ${sameDay ? '' : '明日 '}${two(next.hour)}:${two(next.minute)} ごろ';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('水分補給', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '軽い脱水は眠気とだるさを強めます。決めた間隔で「一口」をすすめる'
              '通知を出します。アプリを閉じていても届きます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: h.enabled,
              onChanged: (v) => h.setEnabled(v),
              title: const Text('水分補給を知らせる'),
              subtitle: Text(
                nextText(),
                style: TextStyle(fontSize: 12, color: c.textDim),
              ),
            ),
            const SizedBox(height: 6),
            Text('間隔', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (final m in HydrationService.intervals)
                    ButtonSegment(value: m, label: Text('$m分')),
                ],
                selected: {h.intervalMinutes},
                showSelectedIcon: false,
                onSelectionChanged: h.enabled
                    ? (s) => h.setInterval(s.first)
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            Text('知らせる時間帯', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _HourDropdown(
                    value: h.fromHour,
                    enabled: h.enabled,
                    onChanged: (v) => h.setHours(from: v),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('〜'),
                ),
                Expanded(
                  child: _HourDropdown(
                    value: h.toHour,
                    enabled: h.enabled,
                    onChanged: (v) => h.setHours(to: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '時刻はおおよそです。省電力の仕組みで数分遅れることがあり、'
              'メーカーの省電力設定によっては届かないこともあります。'
              '届かないときは、このアプリの電池の最適化を外してみてください。',
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

class _HourDropdown extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  const _HourDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        for (var hr = 0; hr < 24; hr++)
          DropdownMenuItem(value: hr, child: Text('$hr時')),
      ],
      onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
    );
  }
}
