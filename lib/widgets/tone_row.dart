import 'package:flutter/material.dart';

import '../services/alarm_service.dart';

/// アラーム音の種類。設定の「検知の設定」に置く。
class ToneRow extends StatelessWidget {
  final AlarmService alarm;
  const ToneRow({super.key, required this.alarm});

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


