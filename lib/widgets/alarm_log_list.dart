import 'package:flutter/material.dart';

import '../services/stats_service.dart';
import '../theme/app_theme.dart';

/// 今日の検知の一覧。記録タブに置く。
class AlarmLogList extends StatelessWidget {
  final StatsService stats;
  const AlarmLogList({super.key, required this.stats});

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
